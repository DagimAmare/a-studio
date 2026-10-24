import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/ethiopian.dart';
import '../core/format.dart';
import '../models/models.dart';
import 'activity.dart';
import 'db.dart';
import 'notification_service.dart';
import 'session.dart';

/// What a client is putting together on the booking screen. Kept in memory
/// so signing in halfway through does not lose it.
class BookingDraft {
  BookingDraft(this.studio);

  final Studio studio;
  final Set<String> serviceIds = {};
  int people = 1;
  DateTime? date;
  int? startMin;
  String place = 'studio';
  String subCity = '';
  String area = '';
  String landmark = '';
  String notes = '';

  static BookingDraft? pending;

  List<ServiceItem> get selected =>
      studio.activeServices.where((s) => serviceIds.contains(s.id)).toList();

  int get durationMin =>
      selected.fold<int>(0, (a, s) => a + s.durationMin) * max(1, people);

  int get servicesTotal => selected
      .where((s) => !s.priceHidden)
      .fold<int>(0, (a, s) => a + s.price) *
      max(1, people);

  int get travelFee => place == 'studio' ? 0 : studio.travelFee;
  int get total => servicesTotal + travelFee;
  bool get totalIsFrom => selected.any((s) => s.priceFrom);
  bool get hasHiddenPrice => selected.any((s) => s.priceHidden);

  int get depositAmount {
    final raw = total * studio.depositPercent / 100;
    return (raw / 10).round() * 10;
  }

  bool get readyForTime => selected.isNotEmpty;
  bool get readyForPlace => readyForTime && date != null && startMin != null;
  bool get placeComplete =>
      place == 'studio' || (subCity.isNotEmpty && landmark.trim().isNotEmpty);
}

class BookingService {
  BookingService._();

  static Stream<List<Booking>> _mine(String field) => Db.bookings
      .where(field, isEqualTo: Session.instance.uid)
      .limit(300)
      .snapshots()
      .map((q) {
        final list = q.docs.map(Booking.fromDoc).toList();
        list.sort((a, b) => (b.startAt ?? DateTime(2100))
            .compareTo(a.startAt ?? DateTime(2100)));
        return list;
      });

  static Stream<List<Booking>> asClient() => _mine('clientUid');
  static Stream<List<Booking>> asArtist() => _mine('artistUid');

  static Stream<Booking?> watch(String id) => Db.bookings
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Booking.fromDoc(d) : null);

  /// Busy intervals [[startMin, endMin], ...] for an artist on a day,
  /// maintained by the Cloud Function from confirmed and pending bookings.
  static Future<List<List<int>>> busyFor(String artistUid, String day) async {
    try {
      final d = await Db.busy.doc('${artistUid}_$day').get().timeout(Db.timeout);
      final raw = d.data()?['intervals'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => [
                (m['start'] as num?)?.toInt() ?? 0,
                (m['end'] as num?)?.toInt() ?? 0,
              ])
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<String> request(BookingDraft d) async {
    final s = Session.instance;
    final date = d.date!;
    final start = d.startMin!;
    // Appointments are in Addis Ababa time (UTC+3), whatever the
    // client's device timezone is (diaspora clients book from abroad).
    final startAt = addisToUtc(date, start);
    final ref = Db.bookings.doc();
    final code = bookingRef(Random().nextInt(9000));
    await ref.set({
      'ref': code,
      'clientUid': s.uid,
      'clientName': s.displayName,
      'clientPhone': s.profile?.phone ?? '',
      'clientEmail': s.profile?.email ?? s.user?.email ?? '',
      'artistUid': d.studio.uid,
      'artistName': d.studio.name,
      'artistHandle': d.studio.handle,
      'items': d.selected
          .map((x) => BookingItem(x.id, x.name, x.durationMin, x.priceMode, x.price).toMap())
          .toList(),
      'people': d.people,
      'total': d.total,
      'totalIsFrom': d.totalIsFrom,
      'hasHiddenPrice': d.hasHiddenPrice,
      'travelFee': d.travelFee,
      'durationMin': d.durationMin,
      'date': dateKey(date),
      'startMin': start,
      'startAt': Timestamp.fromDate(startAt),
      'place': d.place,
      'subCity': d.subCity,
      'area': d.area.trim(),
      'landmark': d.landmark.trim(),
      'notes': d.notes.trim(),
      'depositPercent': d.studio.depositPercent,
      'depositAmount': d.depositAmount,
      'policy': d.studio.cancellationPolicy,
      'status': BookingStatus.requested,
      'reviewed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout);
    NotificationService.notify(
      toUid: d.studio.uid,
      type: 'booking_request',
      title: 'New booking request $code',
      body:
          '${s.displayName} · ${d.selected.map((x) => x.name).join(', ')} · ${dayLabel(date)} (${ethDayMonth(date)}) at ${clockLabel(start)}',
      link: '/bookings/${ref.id}',
      refId: ref.id,
    );
    Activity.log('booking_request', targetType: 'booking', targetId: ref.id, summary: '$code @${d.studio.handle}');
    return ref.id;
  }

  static Future<void> _update(Booking b, Map<String, dynamic> data,
      {required String toUid,
      required String type,
      required String title,
      required String body,
      required String log}) async {
    await Db.bookings.doc(b.id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout);
    NotificationService.notify(
        toUid: toUid, type: type, title: title, body: body, link: '/bookings/${b.id}', refId: b.id);
    Activity.log(log, targetType: 'booking', targetId: b.id, summary: b.ref);
  }

  static String _when(Booking b) {
    final d = b.date.isEmpty ? null : parseDateKey(b.date);
    return d == null ? '' : '${dayLabel(d)} (${ethDayMonth(d)}) at ${clockLabel(b.startMin)}';
  }

  // ---- artist actions

  static Future<void> accept(Booking b, PaymentDetails pay) {
    final needsDeposit = b.depositAmount > 0;
    return _update(
      b,
      {
        'status': needsDeposit ? BookingStatus.accepted : BookingStatus.confirmed,
        'paymentInstructions': pay.toMap(),
      },
      toUid: b.clientUid,
      type: needsDeposit ? 'booking_accepted' : 'booking_confirmed',
      title: needsDeposit
          ? '${b.artistName} accepted ${b.ref}'
          : '${b.ref} is confirmed',
      body: needsDeposit
          ? 'Pay the ${b.depositAmount} Birr deposit to lock in ${_when(b)}.'
          : 'See you ${_when(b)}.',
      log: 'booking_accept',
    );
  }

  static Future<void> decline(Booking b, String reason) => _update(
        b,
        {'status': BookingStatus.declined, 'declineReason': reason},
        toUid: b.clientUid,
        type: 'booking_declined',
        title: '${b.artistName} cannot take ${b.ref}',
        body: reason.isEmpty ? 'Try another time or another artist.' : reason,
        log: 'booking_decline',
      );

  static Future<void> confirmDeposit(Booking b) => _update(
        b,
        {'status': BookingStatus.confirmed},
        toUid: b.clientUid,
        type: 'booking_confirmed',
        title: '${b.ref} is confirmed',
        body: 'Deposit received. See you ${_when(b)}.',
        log: 'booking_confirm_deposit',
      );

  static Future<void> paymentNotReceived(Booking b) => _update(
        b,
        {'status': BookingStatus.accepted},
        toUid: b.clientUid,
        type: 'booking_payment_issue',
        title: 'Deposit not found for ${b.ref}',
        body: '${b.artistName} could not find your payment. Check the reference and send it again.',
        log: 'booking_payment_rejected',
      );

  static Future<void> complete(Booking b) => _update(
        b,
        {'status': BookingStatus.completed},
        toUid: b.clientUid,
        type: 'booking_completed',
        title: 'How was your glam?',
        body: 'Leave a review for ${b.artistName}. It helps other clients choose.',
        log: 'booking_complete',
      );

  static Future<void> noShow(Booking b) => _update(
        b,
        {'status': BookingStatus.noShow},
        toUid: b.clientUid,
        type: 'booking_no_show',
        title: '${b.ref} was marked as a no-show',
        body: 'If this is a mistake, message ${b.artistName}.',
        log: 'booking_no_show',
      );

  static Future<void> cancelByArtist(Booking b, String reason) => _update(
        b,
        {'status': BookingStatus.cancelledArtist, 'cancelReason': reason},
        toUid: b.clientUid,
        type: 'booking_cancelled',
        title: '${b.artistName} cancelled ${b.ref}',
        body: reason.isEmpty
            ? 'Your deposit, if paid, is due back in full.'
            : '$reason. Your deposit, if paid, is due back in full.',
        log: 'booking_cancel_artist',
      );

  // ---- client actions

  static Future<void> submitPayment(Booking b,
          {required String method, required String reference, required int amount}) =>
      _update(
        b,
        {
          'status': BookingStatus.depositSubmitted,
          'payment': {
            'method': method,
            'reference': reference.trim(),
            'amount': amount,
            'submittedAt': Timestamp.now(),
          },
        },
        toUid: b.artistUid,
        type: 'booking_deposit',
        title: 'Deposit sent for ${b.ref}',
        body: '${b.clientName} sent $amount Birr by $method, reference ${reference.trim()}. Check and confirm.',
        log: 'booking_deposit_submit',
      );

  static Future<void> cancelByClient(Booking b, String reason) => _update(
        b,
        {'status': BookingStatus.cancelledClient, 'cancelReason': reason},
        toUid: b.artistUid,
        type: 'booking_cancelled',
        title: '${b.clientName} cancelled ${b.ref}',
        body: reason.isEmpty ? _when(b) : '$reason · ${_when(b)}',
        log: 'booking_cancel_client',
      );
}
