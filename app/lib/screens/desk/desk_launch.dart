import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../theme/colors.dart';

/// One of the four things a studio needs before it can go live.
class LaunchStep {
  final String id;
  final String tab;
  final bool done;
  final String titleEn;
  final String titleAm;
  final String hintEn;
  final String hintAm;
  final String actionEn;
  final String actionAm;
  const LaunchStep(this.id, this.tab, this.done, this.titleEn, this.titleAm, this.hintEn, this.hintAm,
      this.actionEn, this.actionAm);

  String title(BuildContext c) => c.tr(titleEn, titleAm);
  String hint(BuildContext c) => c.tr(hintEn, hintAm);
  String action(BuildContext c) => c.tr(actionEn, actionAm);
}

/// What publishing needs, in the order we guide her through it. The same
/// four steps appear on the Desk, on Home and in the getting-started
/// emails (functions/lib/onboarding.js, studioState).
List<LaunchStep> launchSteps(Studio s, int looks) => [
      LaunchStep(
        'photo',
        'profile',
        s.avatarUrl.isNotEmpty,
        'Profile photo',
        'የመገለጫ ፎቶ',
        'A clear photo of you, so clients know who is coming.',
        'ደንበኞች ማን እንደሚመጣ እንዲያውቁ የእርስዎ ግልጽ ፎቶ።',
        'Add my photo',
        'ፎቶዬን ጨምር',
      ),
      LaunchStep(
        'services',
        'services',
        s.activeServices.isNotEmpty,
        'Services and prices',
        'አገልግሎቶች እና ዋጋዎች',
        'At least one, with a price, a starting price or price on request.',
        'ቢያንስ አንድ፣ ከዋጋ፣ ከመነሻ ዋጋ ወይም ከ«በጥያቄ» ጋር።',
        'Add a service',
        'አገልግሎት ጨምር',
      ),
      LaunchStep(
        'looks',
        'portfolio',
        looks > 0,
        'Photos of your work',
        'የሥራዎ ፎቶዎች',
        looks >= 6 ? '$looks photos and videos. Lovely.' : 'Six or more is best ($looks so far).',
        looks >= 6 ? '$looks ፎቶዎች እና ቪዲዮዎች። ያምራል።' : 'ስድስት እና ከዚያ በላይ ቢሆን ይመረጣል (እስካሁን $looks)።',
        'Add my work',
        'ሥራዬን ጨምር',
      ),
      LaunchStep(
        'hours',
        'hours',
        s.hours.isNotEmpty,
        'Working hours',
        'የሥራ ሰዓት',
        'The days and times clients can book you.',
        'ደንበኞች ሊይዙዎት የሚችሉባቸው ቀናት እና ሰዓቶች።',
        'Set my hours',
        'ሰዓቴን አስቀምጥ',
      ),
    ];

LaunchStep? nextLaunchStep(List<LaunchStep> steps) {
  for (final s in steps) {
    if (!s.done) return s;
  }
  return null;
}

/// A slim bar above every Desk tab until the studio is live: where she is
/// in the four steps, and a button to the next one.
class LaunchBar extends StatelessWidget {
  final List<LaunchStep> steps;
  final String currentTab;
  final ValueChanged<String> onOpen;
  const LaunchBar({super.key, required this.steps, required this.currentTab, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final done = steps.where((s) => s.done).length;
    final next = nextLaunchStep(steps);
    LaunchStep? here;
    for (final s in steps) {
      if (s.tab == currentTab) here = s;
    }

    final String text;
    String? button;
    var target = 'overview';
    if (next == null) {
      text = context.tr('All four steps are done. Publish your studio to go live.',
          'አራቱም እርምጃዎች ተጠናቀዋል። አሁን ስቱዲዮዎን ይክፈቱ።');
      button = context.tr('Publish', 'ክፈት');
    } else if (here != null && !here.done) {
      final n = steps.indexOf(here) + 1;
      text = context.tr('Step $n of ${steps.length} to go live: ${here.title(context)}. ${here.hint(context)}',
          'ለመክፈት ደረጃ $n ከ${steps.length}፡ ${here.title(context)}። ${here.hint(context)}');
    } else if (here != null) {
      text = context.tr('Done. Next: ${next.title(context)}.', 'ተጠናቋል። ቀጣዩ፡ ${next.title(context)}።');
      button = next.action(context);
      target = next.tab;
    } else {
      text = context.tr('$done of ${steps.length} steps done to go live. Next: ${next.title(context)}.',
          'ለመክፈት ከ${steps.length} እርምጃዎች $done ተጠናቀዋል። ቀጣዩ፡ ${next.title(context)}።');
      button = next.action(context);
      target = next.tab;
    }

    return Material(
      color: AppColors.petal.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          const Icon(Icons.rocket_launch_outlined, size: 20, color: AppColors.rouge),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: t.textTheme.bodyMedium?.copyWith(color: AppColors.cocoa))),
          if (button != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => onOpen(target),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(button),
            ),
          ],
        ]),
      ),
    );
  }
}
