import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'activity.dart';
import 'db.dart';
import 'media_service.dart';
import 'session.dart';

class StudioService {
  StudioService._();

  static Stream<Studio?> watch(String uid) => Db.studios
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? Studio.fromMap(d.id, d.data()!) : null);

  /// All live studios. Small enough to filter on the device (single-filter
  /// queries only, so no composite index can ever be missing).
  static Stream<List<Studio>> live() => Db.studios
      .where('status', isEqualTo: 'live')
      .limit(500)
      .snapshots()
      .map((q) => q.docs.map((d) => Studio.fromMap(d.id, d.data())).toList());

  static Future<String?> uidForHandle(String handle) async {
    final d = await Db.handles.doc(handle).get().timeout(Db.timeout);
    final uid = d.data()?['uid'];
    return uid is String ? uid : null;
  }

  static Future<bool> handleAvailable(String handle) async {
    final d = await Db.handles.doc(handle).get().timeout(Db.timeout);
    if (!d.exists) return true;
    return d.data()?['uid'] == Session.instance.uid;
  }

  static Future<void> create({
    required String handle,
    required String name,
    required List<String> specialties,
    required List<String> subCities,
    required bool atStudio,
    required bool homeVisits,
    required bool venueVisits,
    required String studioArea,
    required String whatsapp,
    required String telegram,
    required List<ServiceItem> services,
  }) async {
    final uid = Session.instance.uid;
    final batch = Db.fs.batch();
    batch.set(Db.handles.doc(handle), {
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(Db.studios.doc(uid), {
      'handle': handle,
      'name': name.trim(),
      'tagline': '',
      'bio': '',
      'specialties': specialties,
      'subCities': subCities,
      'workModes': {'studio': atStudio, 'home': homeVisits, 'venue': venueVisits},
      'studioArea': studioArea.trim(),
      'travelFee': 0,
      'whatsapp': whatsapp,
      'telegram': telegram,
      'avatarUrl': '',
      'coverUrl': '',
      'coverType': 'image',
      'status': 'draft',
      'verification': 'none',
      'decor': const StudioDecor().toMap(),
      'services': services.map((s) => s.toMap()).toList(),
      'hours': {
        for (final k in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'])
          k: {'start': 7 * 60, 'end': 19 * 60},
      },
      'bufferMin': 30,
      'noticeHours': 12,
      'blockedDates': <String>[],
      'depositPercent': 30,
      'cancellationPolicy': 'standard',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
        Db.users.doc(uid), {'role': 'artist'}, SetOptions(merge: true));
    await batch.commit().timeout(Db.timeout);
    Activity.log('studio_create', targetType: 'studio', targetId: uid, summary: handle);
  }

  static Future<void> update(Map<String, dynamic> data, {String log = 'studio_update'}) async {
    final uid = Session.instance.uid;
    await Db.studios
        .doc(uid)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(Db.timeout);
    Activity.log(log, targetType: 'studio', targetId: uid, summary: data.keys.join(', '));
  }

  static Future<void> changeHandle(String oldHandle, String newHandle) async {
    final uid = Session.instance.uid;
    final batch = Db.fs.batch();
    batch.set(Db.handles.doc(newHandle), {
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(Db.studios.doc(uid), {
      'handle': newHandle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (oldHandle.isNotEmpty) batch.delete(Db.handles.doc(oldHandle));
    await batch.commit().timeout(Db.timeout);
    Activity.log('studio_handle', targetType: 'studio', targetId: uid, summary: '$oldHandle -> $newHandle');
  }

  /// Go live right away with a New badge; admin verification follows.
  static Future<void> publish(Studio s) => update({
        'status': 'live',
        if (s.publishedAt == null) 'publishedAt': FieldValue.serverTimestamp(),
        if (s.verification == 'none' || s.verification == 'rejected')
          'verification': 'pending',
      }, log: 'studio_publish');

  static Future<void> unpublish() => update({'status': 'draft'}, log: 'studio_unpublish');

  static Future<void> saveServices(List<ServiceItem> services) =>
      update({'services': services.map((s) => s.toMap()).toList()}, log: 'services_update');

  static String newServiceId() =>
      'svc_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

  // ---- payment details (private, owner-only)

  static Future<PaymentDetails> paymentDetails() async {
    final d = await Db.studioPrivate(Session.instance.uid).get().timeout(Db.timeout);
    return PaymentDetails.fromMap(d.data() ?? const {});
  }

  static Future<void> savePaymentDetails(PaymentDetails p) async {
    await Db.studioPrivate(Session.instance.uid)
        .set({...p.toMap(), 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(Db.timeout);
    Activity.log('payment_details_update', targetType: 'studio', targetId: Session.instance.uid);
  }

  // ---- verification files (private)

  static DocumentReference<Map<String, dynamic>> verificationRef(String uid) =>
      Db.studios.doc(uid).collection('private').doc('verification');

  static Stream<Map<String, dynamic>> verificationFiles(String uid) =>
      verificationRef(uid).snapshots().map((d) => d.data() ?? <String, dynamic>{});

  /// [kind] is 'id' (Kebele ID or Fayda) or 'work' (short video of her working).
  static Future<void> saveVerificationFile(String kind, String path) async {
    final uid = Session.instance.uid;
    await verificationRef(uid).set({
      kind: path,
      '${kind}At': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(Db.timeout);
    Activity.log('verification_upload', targetType: 'studio', targetId: uid, summary: kind);
  }

  // ---- looks (portfolio)

  static Stream<List<Look>> looksFor(String uid) => Db.looks
      .where('studioUid', isEqualTo: uid)
      .limit(200)
      .snapshots()
      .map((q) {
        final list = q.docs.map(Look.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2100))
            .compareTo(a.createdAt ?? DateTime(2100)));
        return list;
      });

  static Stream<List<Look>> trending({int limit = 60}) => Db.looks
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map(Look.fromDoc).toList());

  static Future<void> addLook(Studio s, UploadResult up,
      {String caption = '', String occasion = ''}) async {
    final ref = await Db.looks.add({
      'studioUid': s.uid,
      'studioHandle': s.handle,
      'studioName': s.name,
      'url': up.url,
      'thumbUrl': up.thumbUrl,
      'type': up.type,
      'caption': caption,
      'occasion': occasion,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout);
    Activity.log('look_add', targetType: 'look', targetId: ref.id, summary: up.type);
  }

  static Future<void> updateLook(String id, {String? caption, String? occasion}) =>
      Db.looks.doc(id).update({
        if (caption != null) 'caption': caption,
        if (occasion != null) 'occasion': occasion,
      }).timeout(Db.timeout);

  static Future<void> deleteLook(Look look) async {
    await Db.looks.doc(look.id).delete().timeout(Db.timeout);
    MediaService.delete(look.url);
    if (look.thumbUrl.isNotEmpty) MediaService.delete(look.thumbUrl);
    Activity.log('look_delete', targetType: 'look', targetId: look.id);
  }
}
