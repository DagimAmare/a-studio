import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'db.dart';
import 'session.dart';

/// In-app notifications. The Cloud Function turns each one into a push
/// and, for the important types, an email from brush@astudio.hepius.co.
class NotificationService {
  NotificationService._();

  static Stream<List<AppNotification>> mine() {
    final uid = Session.instance.uid;
    return Db.notifications
        .where('toUid', isEqualTo: uid)
        .limit(200)
        .snapshots()
        .map((q) {
      final list = q.docs.map(AppNotification.fromDoc).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(2100))
          .compareTo(a.createdAt ?? DateTime(2100)));
      return list;
    });
  }

  /// Fire-and-forget: a notification must never break the action behind it.
  static void notify({
    required String toUid,
    required String type,
    required String title,
    required String body,
    String link = '',
    String refId = '',
    bool email = true,
    String? docId,
  }) {
    final s = Session.instance;
    if (!s.signedIn || toUid.isEmpty || toUid == s.uid) return;
    final data = {
      'toUid': toUid,
      'fromUid': s.uid,
      'fromName': s.displayName,
      'type': type,
      'title': title,
      'body': body.length > 400 ? body.substring(0, 400) : body,
      'link': link,
      // The booking or chat this is about. The rules check that sender and
      // receiver really are the two people on it.
      'refId': refId,
      'email': email,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final ref = docId == null ? Db.notifications.doc() : Db.notifications.doc(docId);
    ref.set(data).timeout(Db.timeout).catchError((_) {});
  }

  static void markRead(String id) {
    Db.notifications
        .doc(id)
        .update({'read': true})
        .timeout(Db.timeout)
        .catchError((_) {});
  }

  static Future<void> markAllRead(List<AppNotification> list) async {
    final batch = Db.fs.batch();
    var n = 0;
    for (final x in list.where((x) => !x.read)) {
      batch.update(Db.notifications.doc(x.id), {'read': true});
      n++;
      if (n >= 450) break;
    }
    if (n > 0) await batch.commit().timeout(Db.timeout);
  }

  static Future<void> delete(String id) =>
      Db.notifications.doc(id).delete().timeout(Db.timeout);
}
