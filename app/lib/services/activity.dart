import 'package:cloud_firestore/cloud_firestore.dart';

import 'db.dart';
import 'session.dart';

/// Backstage activity log. Every meaningful action writes one line.
/// Message content is never logged, only that a message was sent.
class Activity {
  Activity._();

  static void log(String type,
      {String targetType = '', String targetId = '', String summary = ''}) {
    final s = Session.instance;
    if (!s.signedIn) return;
    Db.activity.add({
      'actorUid': s.uid,
      'actorName': s.displayName,
      'type': type,
      'targetType': targetType,
      'targetId': targetId,
      'summary': summary.length > 280 ? summary.substring(0, 280) : summary,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout).catchError((_) => Db.activity.doc());
  }
}
