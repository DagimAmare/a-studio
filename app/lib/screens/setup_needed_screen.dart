import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../l10n/tr.dart';
import '../theme/colors.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

/// Shown only if the build has no Firebase config yet.
class SetupNeededScreen extends StatelessWidget {
  const SetupNeededScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Monogram(size: 64),
                const SizedBox(height: 22),
                const Wordmark(size: 30),
                const SizedBox(height: 18),
                const TibebBorder(),
                const SizedBox(height: 18),
                Text(context.tr('Where Addis gets ready. Opening soon.', 'አዲስ የምትዘጋጅበት። በቅርቡ ይከፈታል።'),
                    textAlign: TextAlign.center, style: t.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(AppConfig.supportEmail, style: t.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.search_off,
        title: context.tr('We could not find that page', 'ያንን ገጽ ማግኘት አልቻልንም'),
        body: context.tr('The link may be old, or the studio has moved.',
            'ሊንኩ ያረጀ ሊሆን ይችላል ወይም ስቱዲዮው ተዛውሯል።'),
        action: FilledButton(
          onPressed: () => context.go('/explore'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
          child: Text(context.tr('Explore artists', 'ባለሙያዎችን ያስሱ')),
        ),
      );
}
