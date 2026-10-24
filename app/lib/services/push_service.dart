import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import 'db.dart';

/// Web push through Firebase Cloud Messaging. Tokens live under
/// users/{uid}/push_tokens (owner-only), one doc per browser or phone.
/// Permission is only requested from a button, never on page load.
class PushService {
  PushService._();

  static String? _current;
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static String _docId(String token) => token.replaceAll('/', '_');

  static Future<void> _save(String uid, String token) => Db.users
      .doc(uid)
      .collection('push_tokens')
      .doc(_docId(token))
      .set({
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(Db.timeout);

  static Future<void> _register(String uid) async {
    final token = await FirebaseMessaging.instance
        .getToken(vapidKey: kIsWeb ? AppConfig.vapidKey : null)
        .timeout(const Duration(seconds: 25));
    if (token != null && token.isNotEmpty) {
      _current = token;
      enabled.value = true;
      await _save(uid, token);
    }
  }

  /// Called after sign-in: re-registers silently only if the browser
  /// already granted permission earlier.
  static Future<void> refreshIfGranted(String uid) async {
    if (uid.isEmpty || !AppConfig.pushConfigured) return;
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings()
          .timeout(const Duration(seconds: 10));
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _register(uid);
      }
    } catch (_) {}
  }

  /// From the "Turn on notifications" button. Returns true when enabled.
  static Future<bool> enable(String uid) async {
    if (uid.isEmpty || !AppConfig.pushConfigured) return false;
    try {
      final settings = await FirebaseMessaging.instance
          .requestPermission()
          .timeout(const Duration(seconds: 60));
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }
      await _register(uid);
      return enabled.value;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearToken(String uid) async {
    final token = _current;
    _current = null;
    enabled.value = false;
    if (uid.isEmpty || token == null) return;
    try {
      await Db.users
          .doc(uid)
          .collection('push_tokens')
          .doc(_docId(token))
          .delete()
          .timeout(Db.timeout);
    } catch (_) {}
  }
}
