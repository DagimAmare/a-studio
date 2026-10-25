import 'package:flutter/foundation.dart' show kIsWeb;

/// App-wide constants. Nothing secret lives here: it all ships to browsers.
class AppConfig {
  AppConfig._();

  static const String appName = 'A Studio';
  static const String productionUrl = 'https://astudio.hepius.co';
  static const String supportEmail = 'brush@astudio.hepius.co';

  /// Shown at the bottom of Account so testers can confirm which build is live.
  static const String buildLabel = 'v0.1.3 (build 4) · 25 Oct 2026';

  /// Bump when the Terms or Privacy Policy change in a way users must accept.
  static const String termsVersion = '2026-10-24';

  /// Web Push public key (Firebase console > Cloud Messaging > Web Push
  /// certificates). Safe to ship: it is the PUBLIC half of the pair.
  static const String vapidKey =
      'BCmT_LuABToZ35JJiEb8DJ3Uj5xz8z5X5Hrm1bZiOUNCdmlp81zmWhC72e-8oPqyqvEmVpU8peKS-PxOfc-y2w8';
  static bool get pushConfigured => vapidKey.length > 40;

  /// Same origin in production, so uploads and media need no CORS.
  static String get origin {
    if (kIsWeb) {
      final base = Uri.base;
      if (base.host == 'astudio.hepius.co') return base.origin;
    }
    return productionUrl;
  }

  static String get uploadEndpoint => '$origin/api/upload.php';
  static String get mediaEndpoint => '$origin/api/media.php';

  /// Cloud Functions (2nd gen, europe-west1) HTTP endpoints.
  static const String functionsBase =
      'https://europe-west1-astudio-207.cloudfunctions.net';
  static String get phoneCodeEndpoint => '$functionsBase/phoneCode';

  /// Sign in and phone checks with a one-time code. Turn on once an SMS or
  /// Telegram code provider is set up for the functions (see DEPLOY.md).
  static const bool phoneCodes = false;

  /// Lets Backstage broadcasts go out by SMS too (paid per message). Turn on
  /// once the SMS provider is set up for the functions.
  static const bool smsBroadcasts = false;

  static const String termsPath = '/terms.html';
  static const String privacyPath = '/privacy.html';
  static const String deletionPath = '/delete-account.html';

  static String studioLink(String handle) => '$productionUrl/$handle';

  /// Single-segment paths the app owns. Handles may never use these.
  static const Set<String> reservedHandles = {
    'about', 'account', 'admin', 'api', 'app', 'artist', 'artists',
    'backstage', 'blog', 'book', 'booking', 'bookings', 'brush', 'cache',
    'careers', 'chat', 'contact', 'delete-account', 'desk', 'explore',
    'faq', 'help', 'home', 'icons', 'inbox', 'legal', 'login', 'logout',
    'media', 'message', 'messages', 'notifications', 'privacy', 'search', 'settings',
    'shop', 'signin', 'signup', 'studio', 'studios', 'support', 'terms',
    'vanity', 'welcome', 'www', 'astudio', 'a-studio', 'hepius',
  };
}
