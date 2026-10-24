import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'activity.dart';
import 'auth_service.dart';
import 'db.dart';
import 'media_service.dart';
import 'push_service.dart';
import 'session.dart';
import 'studio_service.dart';

/// Self-service account deletion (Settings > Delete account).
/// Order: confirm identity, purge media, delete owned data, delete login.
/// A Cloud Function (onAuthUserDeleted) sweeps anything left behind and
/// anonymises the name on past bookings and reviews.
class AccountService {
  AccountService._();

  static Object? _plain(Object? v) {
    if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
    if (v is Map) return v.map((k, x) => MapEntry('$k', _plain(x)));
    if (v is List) return v.map(_plain).toList();
    if (v is GeoPoint) return {'lat': v.latitude, 'lng': v.longitude};
    return v;
  }

  static Future<List<Map<String, dynamic>>> _docs(Query<Map<String, dynamic>> q) async {
    try {
      final snap = await q.get().timeout(const Duration(seconds: 40));
      return [
        for (final d in snap.docs) {'id': d.id, ...(_plain(d.data()) as Map<String, dynamic>)}
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Everything A Studio holds about the signed-in person, as JSON
  /// (the right of access under Proclamation 1321/2024).
  static Future<String> exportData() async {
    final s = Session.instance;
    final uid = s.uid;
    Future<Map<String, dynamic>?> one(DocumentReference<Map<String, dynamic>> ref) async {
      try {
        final d = await ref.get().timeout(Db.timeout);
        final data = d.data();
        return data == null ? null : _plain(data) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }

    final out = <String, dynamic>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'account': {
        'uid': uid,
        'email': s.user?.email,
        'emailVerified': s.user?.emailVerified,
        'signInMethods': s.user?.providerData.map((p) => p.providerId).toList(),
      },
      'profile': await one(Db.users.doc(uid)),
      'studio': await one(Db.studios.doc(uid)),
      'studioPaymentDetails': await one(Db.studioPrivate(uid)),
      'portfolio': await _docs(Db.looks.where('studioUid', isEqualTo: uid)),
      'bookingsAsClient': await _docs(Db.bookings.where('clientUid', isEqualTo: uid)),
      'bookingsAsArtist': await _docs(Db.bookings.where('artistUid', isEqualTo: uid)),
      'reviewsWritten': await _docs(Db.reviews.where('clientUid', isEqualTo: uid)),
      'reviewsReceived': await _docs(Db.reviews.where('studioUid', isEqualTo: uid)),
      'listings': await _docs(Db.listings.where('sellerUid', isEqualTo: uid)),
      'notifications': await _docs(Db.notifications.where('toUid', isEqualTo: uid)),
      'conversations': await _docs(Db.chats.where('participants', arrayContains: uid)),
    };
    Activity.log('data_export', targetType: 'user', targetId: uid);
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  static Future<void> deleteEverything({String? password}) async {
    final s = Session.instance;
    final uid = s.uid;
    if (uid.isEmpty) return;

    await AuthService.reauthenticate(password: password);
    Activity.log('account_delete', targetType: 'user', targetId: uid, summary: s.profile?.email ?? '');

    await MediaService.purgeAll();

    Future<void> safe(Future<void> Function() f) async {
      try {
        await f().timeout(Db.timeout);
      } catch (_) {}
    }

    final studio = s.studio;
    await safe(() => StudioService.verificationRef(uid).delete());
    if (studio != null) {
      await safe(() => Db.studioPrivate(uid).delete());
      await safe(() => Db.studios.doc(uid).delete());
      if (studio.handle.isNotEmpty) {
        await safe(() => Db.handles.doc(studio.handle).delete());
      }
    }
    await safe(() async {
      final looks = await Db.looks.where('studioUid', isEqualTo: uid).get();
      for (final d in looks.docs) {
        await d.reference.delete();
      }
    });
    await safe(() async {
      final listings = await Db.listings.where('sellerUid', isEqualTo: uid).get();
      for (final d in listings.docs) {
        await d.reference.delete();
      }
    });
    await safe(() async {
      final notes = await Db.notifications.where('toUid', isEqualTo: uid).get();
      for (final d in notes.docs) {
        await d.reference.delete();
      }
    });
    await PushService.clearToken(uid);
    await safe(() async {
      final tokens = await Db.users.doc(uid).collection('push_tokens').get();
      for (final d in tokens.docs) {
        await d.reference.delete();
      }
    });
    await safe(() => Db.users.doc(uid).delete());

    await FirebaseAuth.instance.currentUser?.delete();
  }
}
