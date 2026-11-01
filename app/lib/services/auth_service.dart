import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import '../core/browser.dart';
import '../l10n/tr.dart';
import '../platform/media_types.dart';
import '../platform/web_bridge.dart' as bridge;
import 'activity.dart';
import 'db.dart';
import 'session.dart';

class AuthService {
  AuthService._();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Map<String, dynamic> _consent() => {
        'terms': AppConfig.termsVersion,
        'privacy': AppConfig.termsVersion,
        'storageAbroad': true,
        'at': FieldValue.serverTimestamp(),
      };

  /// Email is mandatory for every account (receipts and booking emails).
  static Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    required bool marketing,
    String lang = 'en',
  }) async {
    final cred = await _auth
        .createUserWithEmailAndPassword(email: email.trim(), password: password)
        .timeout(Db.timeout);
    final user = cred.user!;
    try {
      await user.updateDisplayName(name.trim()).timeout(Db.timeout);
    } catch (_) {}
    await createProfile(
      uid: user.uid,
      name: name,
      email: email.trim(),
      phone: phone,
      role: role,
      marketing: marketing,
      lang: lang,
    );
    try {
      await user.sendEmailVerification().timeout(Db.timeout);
    } catch (_) {}
    Activity.log('sign_up', targetType: 'user', targetId: user.uid, summary: role);
  }

  static Future<void> createProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String role,
    required bool marketing,
    String photoUrl = '',
    String lang = 'en',
  }) =>
      Db.users.doc(uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone,
        'photoUrl': photoUrl,
        'role': role,
        'lang': lang,
        'birthday': '',
        'prefs': {'email': true, 'marketing': marketing},
        'status': 'active',
        'consent': _consent(),
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(Db.timeout);

  static Future<void> signIn(String email, String password) async {
    await _auth
        .signInWithEmailAndPassword(email: email.trim(), password: password)
        .timeout(Db.timeout);
    Activity.log('sign_in', summary: 'email');
  }

  /// Instagram, TikTok, Facebook and other app browsers, where Google
  /// refuses to sign anyone in.
  static bool get inEmbeddedBrowser => isEmbeddedBrowser(bridge.userAgent());

  static Future<void> signInWithGoogle() async {
    await _auth.signInWithPopup(GoogleAuthProvider());
    Activity.log('sign_in', summary: 'google');
  }

  static Future<void> sendReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim()).timeout(Db.timeout);

  static Future<void> resendVerification() async {
    await _auth.currentUser?.sendEmailVerification().timeout(Db.timeout);
  }

  // ---- one-time phone codes (Cloud Function `phoneCode`)

  /// [purpose] is 'signin' (signed out, phone already on an account) or
  /// 'verify' (signed in, confirms the phone on the profile).
  static Future<void> sendPhoneCode(String phone,
      {required String purpose, String channel = 'sms'}) async {
    final idToken = purpose == 'verify' ? await _auth.currentUser?.getIdToken() : null;
    await bridge.postJson(AppConfig.phoneCodeEndpoint, {
      'action': 'send',
      'phone': phone,
      'purpose': purpose,
      'channel': channel,
      if (idToken != null) 'idToken': idToken,
    });
  }

  static Future<void> verifyPhoneCode(String phone, String code,
      {required String purpose}) async {
    final idToken = purpose == 'verify' ? await _auth.currentUser?.getIdToken() : null;
    final res = await bridge.postJson(AppConfig.phoneCodeEndpoint, {
      'action': 'verify',
      'phone': phone,
      'code': code.trim(),
      'purpose': purpose,
      if (idToken != null) 'idToken': idToken,
    });
    if (purpose == 'signin') {
      final token = res['token'];
      if (token is! String || token.isEmpty) {
        throw const MediaException('Could not sign you in. Try again.');
      }
      await _auth.signInWithCustomToken(token).timeout(Db.timeout);
      Activity.log('sign_in', summary: 'phone code');
    } else {
      Activity.log('phone_verify', targetType: 'user', targetId: Session.instance.uid);
    }
  }

  /// After the user clicks the link in the verification email.
  static Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload().timeout(Db.timeout);
    final fresh = _auth.currentUser;
    if (fresh == null || !fresh.emailVerified) return false;
    await fresh.getIdToken(true);
    await Session.instance.syncEmailVerified();
    await Session.instance.refreshUser();
    return true;
  }

  static bool get usesPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  /// Required by Firebase before deleting an account.
  static Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (usesPassword) {
      final cred = EmailAuthProvider.credential(
          email: user.email ?? '', password: password ?? '');
      await user.reauthenticateWithCredential(cred).timeout(Db.timeout);
    } else {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    }
  }

  static String friendlyError(Object e) {
    if (e is MediaException) return e.message;
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'user-disabled':
          return 'This account has been disabled. Contact ${AppConfig.supportEmail}.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already uses this email. Try signing in.';
        case 'weak-password':
          return 'Use a password with at least 8 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a few minutes and try again.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Google sign-in was closed before finishing.';
        case 'popup-blocked':
          return _t('Your browser blocked the Google sign-in window. Allow pop-ups for this site and try again.',
              'አሳሽዎ የGoogle መግቢያ መስኮቱን ከልክሏል። ለዚህ ድረ-ገጽ pop-up ፈቅደው እንደገና ይሞክሩ።');
        case 'unauthorized-domain':
          return _t('Google sign-in does not work on this page. Sign in with your email and password.',
              'በዚህ ገጽ በGoogle መግባት አይሠራም። በኢሜይል እና በይለፍ ቃል ይግቡ።');
        case 'operation-not-allowed':
          return _t('Google sign-in is turned off right now. Sign in with your email and password.',
              'በGoogle መግባት ለጊዜው ተዘግቷል። በኢሜይል እና በይለፍ ቃል ይግቡ።');
        case 'web-storage-unsupported':
          return _t('This browser blocks what Google sign-in needs. Open A Studio in Chrome or Safari, or use your email.',
              'ይህ አሳሽ የGoogle መግቢያ የሚያስፈልገውን ይከለክላል። ኤ ስቱዲዮን በChrome ወይም በSafari ይክፈቱ፣ ወይም በኢሜይል ይግቡ።');
        case 'account-exists-with-different-credential':
          return _t('This email already has an A Studio account. Sign in with your email and password.',
              'ይህ ኢሜይል የኤ ስቱዲዮ መለያ አለው። በኢሜይል እና በይለፍ ቃል ይግቡ።');
        case 'network-request-failed':
          return 'No connection. Check your internet and try again.';
        case 'requires-recent-login':
          return 'Please confirm it is you, then try again.';
      }
      return 'Something went wrong (${e.code}). Try again.';
    }
    return 'Something went wrong. Try again.';
  }

  static String _t(String en, String am) => LocaleController.instance.isAmharic ? am : en;
}
