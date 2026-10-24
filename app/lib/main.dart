import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'platform/web_bridge.dart' as bridge;
import 'services/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean links like astudio.hepius.co/hana instead of /#/hana.
  usePathUrlStrategy();
  var ready = false;
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      ready = true;
    } catch (_) {
      ready = false;
    }
  }
  if (ready) Session.instance.start();
  runApp(AStudioApp(firebaseReady: ready));
  // The CSS splash in index.html stays up until the first frame is drawn.
  WidgetsBinding.instance.addPostFrameCallback((_) => bridge.removeSplash());
}
