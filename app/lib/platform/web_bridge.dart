/// Browser-only helpers behind one import. The stub keeps `flutter test`
/// (Dart VM) compiling; the web build gets the real dart:html version.
library;

export 'web_bridge_stub.dart' if (dart.library.html) 'web_bridge_web.dart';
