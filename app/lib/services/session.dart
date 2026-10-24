import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'db.dart';
import 'push_service.dart';

/// Who is signed in, their profile, admin flag, their studio and live
/// unread counts. The router listens to this for redirects.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  User? user;
  UserProfile? profile;
  bool profileLoaded = false;
  bool isAdmin = false;
  Studio? studio;
  bool studioLoaded = false;
  bool started = false;
  bool authKnown = false;
  int unreadChats = 0;
  int unreadNotifications = 0;

  /// True while a sign-up is writing the profile, so the router does not
  /// bounce the new account to /welcome halfway through.
  bool holdRedirects = false;

  final List<StreamSubscription> _subs = [];

  bool get signedIn => user != null;
  bool get isArtist => profile?.isArtist ?? false;
  String get uid => user?.uid ?? '';
  String get displayName {
    final n = profile?.name ?? user?.displayName ?? '';
    if (n.trim().isNotEmpty) return n.trim();
    final e = user?.email ?? '';
    return e.isEmpty ? 'Guest' : e.split('@').first;
  }

  void start() {
    if (started) return;
    started = true;
    FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  Future<void> _cancel() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  Future<void> _onUser(User? u) async {
    await _cancel();
    user = u;
    profile = null;
    profileLoaded = false;
    isAdmin = false;
    studio = null;
    studioLoaded = false;
    unreadChats = 0;
    unreadNotifications = 0;
    if (u == null) {
      authKnown = true;
      profileLoaded = true;
      notifyListeners();
      return;
    }
    authKnown = true;
    notifyListeners();

    _subs.add(Db.users.doc(u.uid).snapshots().listen((snap) {
      final data = snap.data();
      profile = data == null ? null : UserProfile.fromMap(u.uid, data);
      profileLoaded = true;
      notifyListeners();
      if (profile != null && !profile!.emailVerified && (user?.emailVerified ?? false)) {
        unawaited(syncEmailVerified());
      }
    }, onError: (_) {
      profileLoaded = true;
      notifyListeners();
    }));

    _subs.add(Db.studios.doc(u.uid).snapshots().listen((snap) {
      final data = snap.data();
      studio = data == null ? null : Studio.fromMap(u.uid, data);
      studioLoaded = true;
      notifyListeners();
    }, onError: (_) {
      studioLoaded = true;
      notifyListeners();
    }));

    _subs.add(Db.chats
        .where('participants', arrayContains: u.uid)
        .snapshots()
        .listen((q) {
      var total = 0;
      for (final d in q.docs) {
        final unread = d.data()['unread'];
        if (unread is Map && unread[u.uid] is num) {
          total += (unread[u.uid] as num).toInt();
        }
      }
      unreadChats = total;
      notifyListeners();
    }, onError: (_) {}));

    _subs.add(Db.notifications
        .where('toUid', isEqualTo: u.uid)
        .snapshots()
        .listen((q) {
      unreadNotifications =
          q.docs.where((d) => d.data()['read'] != true).length;
      notifyListeners();
    }, onError: (_) {}));

    try {
      final a = await Db.admins.doc(u.uid).get().timeout(Db.timeout);
      isAdmin = a.exists;
      notifyListeners();
    } catch (_) {}

    unawaited(PushService.refreshIfGranted(u.uid));
  }

  /// Sign-out order matters: drop this device's push token while the rules
  /// still see us as signed in (Alfam lesson).
  Future<void> signOut() async {
    final id = uid;
    await PushService.clearToken(id);
    await FirebaseAuth.instance.signOut();
  }

  /// Copies "email verified" from the sign-in token to the profile (and the
  /// studio page). The rules accept it only when the token says so.
  Future<void> syncEmailVerified() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || !u.emailVerified) return;
    try {
      await Db.users.doc(u.uid).update({'emailVerified': true}).timeout(Db.timeout);
      if (studio != null) {
        await Db.studios.doc(u.uid).update({'emailVerified': true}).timeout(Db.timeout);
      }
    } catch (_) {}
  }

  void hold(bool value) {
    holdRedirects = value;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      user = FirebaseAuth.instance.currentUser;
      notifyListeners();
    } catch (_) {}
  }
}

/// Small helper for server timestamps in writes.
Object get serverNow => FieldValue.serverTimestamp();
