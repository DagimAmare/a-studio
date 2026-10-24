import '../config.dart';

final RegExp _handle = RegExp(r'^[a-z0-9][a-z0-9._-]{1,28}[a-z0-9]$');
final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Lowercases and strips characters a handle cannot hold.
String normalizeHandle(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');

/// Null when valid, otherwise an English reason.
String? handleProblem(String handle) {
  if (handle.length < 3) return 'Use at least 3 characters.';
  if (handle.length > 30) return 'Use 30 characters or fewer.';
  if (!_handle.hasMatch(handle)) {
    return 'Letters, numbers, dots, dashes and underscores only, starting and ending with a letter or number.';
  }
  if (AppConfig.reservedHandles.contains(handle)) return 'That name is reserved.';
  return null;
}

bool isEmail(String v) => _email.hasMatch(v.trim());

/// Accepts 09.., 07.., 9.., +251.., 251.. and returns +2519XXXXXXXX,
/// or null when it is not an Ethiopian mobile number.
String? normalizeEthiopianPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('251')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length != 9) return null;
  if (!(d.startsWith('9') || d.startsWith('7'))) return null;
  return '+251$d';
}

/// Digits only, for wa.me links: 2519XXXXXXXX. Accepts foreign numbers too.
String whatsappDigits(String raw) {
  final eth = normalizeEthiopianPhone(raw);
  if (eth != null) return eth.substring(1);
  return raw.replaceAll(RegExp(r'[^0-9]'), '');
}

/// "@hana_glam" or "hana_glam" or a t.me link -> "hana_glam".
String telegramUsername(String raw) {
  var v = raw.trim();
  v = v.replaceAll(RegExp(r'^https?://(t\.me|telegram\.me)/'), '');
  if (v.startsWith('@')) v = v.substring(1);
  return v.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
}
