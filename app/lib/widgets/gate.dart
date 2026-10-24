import 'package:flutter/material.dart';

import '../services/session.dart';
import 'common.dart';

/// Builds its child only once we know who is signed in and their profile
/// has loaded. The router sends signed-out visitors to /signin, so this
/// only ever shows a spinner for a moment.
class SignedInGate extends StatelessWidget {
  final WidgetBuilder builder;
  const SignedInGate({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final s = Session.instance;
        if (!s.authKnown || !s.signedIn || !s.profileLoaded) return const Loading();
        return builder(context);
      },
    );
  }
}
