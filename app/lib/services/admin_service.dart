import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'activity.dart';
import 'db.dart';
import 'media_service.dart';
import 'session.dart';
import 'studio_service.dart';

/// A saved broadcast, in English and Amharic.
class MessageTemplate {
  final String id;
  final String name;
  final String titleEn;
  final String bodyEn;
  final String titleAm;
  final String bodyAm;
  final String link;
  const MessageTemplate({
    required this.id,
    required this.name,
    required this.titleEn,
    required this.bodyEn,
    required this.titleAm,
    required this.bodyAm,
    required this.link,
  });

  factory MessageTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    String s(String k) => m[k] is String ? m[k] as String : '';
    return MessageTemplate(
      id: d.id,
      name: s('name'),
      titleEn: s('titleEn'),
      bodyEn: s('bodyEn'),
      titleAm: s('titleAm'),
      bodyAm: s('bodyAm'),
      link: s('link'),
    );
  }
}

class AdminCounts {
  final int users;
  final int artists;
  final int liveStudios;
  final int pendingVerification;
  final int bookings;
  final int openBookings;
  final int listings;
  final int openReports;
  const AdminCounts({
    this.users = 0,
    this.artists = 0,
    this.liveStudios = 0,
    this.pendingVerification = 0,
    this.bookings = 0,
    this.openBookings = 0,
    this.listings = 0,
    this.openReports = 0,
  });
}

/// Backstage. Every power here is ALSO enforced by the Firestore rules
/// (admins/{uid} must exist), so this UI shipping in the public bundle
/// reveals nothing an attacker could use.
class AdminService {
  AdminService._();

  static Future<int> _count(Query<Map<String, dynamic>> q) async {
    try {
      final r = await q.count().get().timeout(Db.timeout);
      return r.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<AdminCounts> counts() async {
    final results = await Future.wait([
      _count(Db.users),
      _count(Db.users.where('role', isEqualTo: 'artist')),
      _count(Db.studios.where('status', isEqualTo: 'live')),
      _count(Db.studios.where('verification', isEqualTo: 'pending')),
      _count(Db.bookings),
      _count(Db.bookings.where('status', whereIn: ['requested', 'accepted', 'deposit_submitted', 'confirmed'])),
      _count(Db.listings.where('status', isEqualTo: 'active')),
      _count(Db.reports.where('status', isEqualTo: 'open')),
    ]);
    return AdminCounts(
      users: results[0],
      artists: results[1],
      liveStudios: results[2],
      pendingVerification: results[3],
      bookings: results[4],
      openBookings: results[5],
      listings: results[6],
      openReports: results[7],
    );
  }

  static Stream<List<ActivityEntry>> activity({int limit = 300}) => Db.activity
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map(ActivityEntry.fromDoc).toList());

  static Stream<List<Studio>> allStudios() => Db.studios
      .limit(1000)
      .snapshots()
      .map((q) => q.docs.map((d) => Studio.fromMap(d.id, d.data())).toList());

  static Stream<List<UserProfile>> users() => Db.users
      .limit(2000)
      .snapshots()
      .map((q) {
        final list = q.docs.map((d) => UserProfile.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2100))
            .compareTo(a.createdAt ?? DateTime(2100)));
        return list;
      });

  static Stream<List<Booking>> bookings() => Db.bookings
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((q) => q.docs.map(Booking.fromDoc).toList());

  static Stream<List<Listing>> listings() => Db.listings
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((q) => q.docs.map(Listing.fromDoc).toList());

  static Stream<List<Report>> reports() => Db.reports
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((q) => q.docs.map(Report.fromDoc).toList());

  static Future<void> _studio(String uid, Map<String, dynamic> data, String log, String summary) async {
    await Db.studios.doc(uid).update({...data, 'updatedAt': FieldValue.serverTimestamp()}).timeout(Db.timeout);
    Activity.log(log, targetType: 'studio', targetId: uid, summary: summary);
  }

  static Future<void> setVerification(Studio s, String status, {String reason = ''}) async {
    await _studio(s.uid, {
      'verification': status,
      if (status == 'verified') 'verifiedAt': FieldValue.serverTimestamp(),
      'verificationNote': reason,
    }, 'admin_verify', '${s.handle}: $status');
    _notify(s.uid,
        status == 'verified' ? 'Your studio is verified' : 'Verification update',
        status == 'verified'
            ? 'Your Verified badge is now on your page. Congratulations!'
            : (reason.isEmpty ? 'Please check your studio details.' : reason),
        '/desk');
  }

  static Future<void> setFeatured(Studio s, bool featured) =>
      _studio(s.uid, {'featured': featured}, 'admin_feature', '${s.handle}: $featured');

  static Future<void> setBadges(Studio s, List<String> badges) =>
      _studio(s.uid, {'badges': badges}, 'admin_badges', '${s.handle}: ${badges.join(', ')}');

  static Future<void> setStudioStatus(Studio s, String status) =>
      _studio(s.uid, {'status': status}, 'admin_studio_status', '${s.handle}: $status');

  static Future<void> setUserStatus(UserProfile u, String status) async {
    await Db.users.doc(u.uid).update({'status': status}).timeout(Db.timeout);
    Activity.log('admin_user_status', targetType: 'user', targetId: u.uid, summary: '${u.email}: $status');
  }

  static Future<void> setListingStatus(Listing l, String status) async {
    await Db.listings.doc(l.id).update({'status': status, 'updatedAt': FieldValue.serverTimestamp()}).timeout(Db.timeout);
    Activity.log('admin_listing_status', targetType: 'listing', targetId: l.id, summary: '${l.title}: $status');
  }

  static Future<void> resolveReport(Report r, String note) async {
    await Db.reports.doc(r.id).update({
      'status': 'resolved',
      'resolution': note,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': Session.instance.uid,
    }).timeout(Db.timeout);
    Activity.log('admin_report_resolve', targetType: 'report', targetId: r.id, summary: note);
  }

  // ---- verification files

  /// After a decision the ID photo and work video are deleted (privacy).
  static Future<void> clearVerificationFiles(String uid) async {
    try {
      final ref = StudioService.verificationRef(uid);
      final d = await ref.get().timeout(Db.timeout);
      final data = d.data() ?? const <String, dynamic>{};
      for (final k in ['id', 'work']) {
        final path = data[k];
        if (path is String && path.isNotEmpty) await MediaService.deletePrivate(path);
      }
      if (d.exists) {
        await ref.set({
          'id': '',
          'work': '',
          'clearedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(Db.timeout);
      }
    } catch (_) {}
  }

  // ---- templates

  static CollectionReference<Map<String, dynamic>> get _templates => Db.fs.collection('templates');

  static Stream<List<MessageTemplate>> templates() => _templates.limit(200).snapshots().map((q) {
        final list = q.docs.map(MessageTemplate.fromDoc).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  static Future<void> saveTemplate(MessageTemplate t) async {
    final data = {
      'name': t.name,
      'titleEn': t.titleEn,
      'bodyEn': t.bodyEn,
      'titleAm': t.titleAm,
      'bodyAm': t.bodyAm,
      'link': t.link,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (t.id.isEmpty) {
      await _templates.add(data).timeout(Db.timeout);
    } else {
      await _templates.doc(t.id).set(data).timeout(Db.timeout);
    }
    Activity.log('admin_template_save', targetType: 'template', targetId: t.id, summary: t.name);
  }

  static Future<void> deleteTemplate(MessageTemplate t) async {
    await _templates.doc(t.id).delete().timeout(Db.timeout);
    Activity.log('admin_template_delete', targetType: 'template', targetId: t.id, summary: t.name);
  }

  // ---- broadcasts

  static Future<int> audienceCount(String audience) {
    Query<Map<String, dynamic>> q = Db.users;
    if (audience == 'clients') q = q.where('role', isEqualTo: 'client');
    if (audience == 'artists') q = q.where('role', isEqualTo: 'artist');
    return _count(q);
  }

  static String fill(String text, String name) {
    final first = name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).first;
    return text.replaceAll('{first_name}', first.isEmpty ? 'there' : first);
  }

  /// Sends the message to the admin only, exactly as people will get it.
  static Future<void> sendTest({
    required String title,
    required String body,
    required String link,
    required bool email,
  }) async {
    final s = Session.instance;
    await Db.notifications.add({
      'toUid': s.uid,
      'fromUid': s.uid,
      'fromName': 'A Studio',
      'type': 'announcement',
      'title': '[Test] ${fill(title, s.displayName)}',
      'body': fill(body, s.displayName),
      'link': link,
      'email': email,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout);
  }

  static void _notify(String toUid, String title, String body, String link) {
    final s = Session.instance;
    Db.notifications.add({
      'toUid': toUid,
      'fromUid': s.uid,
      'fromName': 'A Studio',
      'type': 'admin',
      'title': title,
      'body': body,
      'link': link,
      'email': true,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout).catchError((_) => Db.notifications.doc());
  }

  /// In-app + push to everyone in the audience, with optional email.
  /// Returns how many people it reached.
  static Future<int> broadcast({
    required String audience, // everyone | clients | artists
    required String title,
    required String body,
    String titleAm = '',
    String bodyAm = '',
    required String link,
    required bool email,
    bool sms = false,
    bool marketingOnly = true,
  }) async {
    Query<Map<String, dynamic>> q = Db.users;
    if (audience == 'clients') q = q.where('role', isEqualTo: 'client');
    if (audience == 'artists') q = q.where('role', isEqualTo: 'artist');
    final users = await q.limit(5000).get().timeout(const Duration(seconds: 60));
    final s = Session.instance;
    var batch = Db.fs.batch();
    var inBatch = 0;
    var total = 0;
    for (final u in users.docs) {
      final data = u.data();
      if (data['status'] == 'suspended') continue;
      final prefs = data['prefs'];
      if (marketingOnly && !(prefs is Map && prefs['marketing'] == true)) continue;
      final name = data['name'] is String ? data['name'] as String : '';
      final am = data['lang'] == 'am' && titleAm.trim().isNotEmpty;
      batch.set(Db.notifications.doc(), {
        'toUid': u.id,
        'fromUid': s.uid,
        'fromName': 'A Studio',
        'type': marketingOnly ? 'campaign' : 'announcement',
        'title': fill(am ? titleAm : title, name),
        'body': fill(am && bodyAm.trim().isNotEmpty ? bodyAm : body, name),
        'link': link,
        'email': email,
        'sms': sms,
        'marketing': marketingOnly,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      inBatch++;
      total++;
      if (inBatch >= 400) {
        await batch.commit().timeout(const Duration(seconds: 60));
        batch = Db.fs.batch();
        inBatch = 0;
      }
    }
    if (inBatch > 0) await batch.commit().timeout(const Duration(seconds: 60));
    Activity.log('admin_broadcast',
        targetType: 'audience', targetId: audience, summary: '$title ($total people, email: $email, sms: $sms)');
    return total;
  }
}
