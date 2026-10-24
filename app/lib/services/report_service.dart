import 'package:cloud_firestore/cloud_firestore.dart';

import 'activity.dart';
import 'db.dart';
import 'session.dart';

class ReportService {
  ReportService._();

  static Future<void> report({
    required String targetType,
    required String targetId,
    required String targetLabel,
    required String reason,
    String details = '',
  }) async {
    final s = Session.instance;
    final ref = await Db.reports.add({
      'reporterUid': s.uid,
      'reporterName': s.displayName,
      'targetType': targetType,
      'targetId': targetId,
      'targetLabel': targetLabel,
      'reason': reason,
      'details': details.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout);
    Activity.log('report_create', targetType: targetType, targetId: targetId, summary: '$reason (${ref.id})');
  }
}
