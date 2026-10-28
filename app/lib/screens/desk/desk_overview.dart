import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';
import '../../core/format.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../platform/web_bridge.dart' as bridge;
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../services/session.dart';
import '../../services/studio_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/phone_verify.dart';
import 'desk_launch.dart';
import 'desk_screen.dart';

class OverviewTab extends StatefulWidget {
  final Studio studio;
  final List<Booking> bookings;
  final ValueChanged<String> onOpen;
  const OverviewTab({super.key, required this.studio, required this.bookings, required this.onOpen});
  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  late final Stream<List<Look>> _looks = StudioService.looksFor(widget.studio.uid);
  late final Stream<Map<String, dynamic>> _verification =
      StudioService.verificationFiles(widget.studio.uid);
  late final Future<PaymentDetails> _pay =
      StudioService.paymentDetails().catchError((_) => const PaymentDetails());
  String _uploading = '';
  double _progress = 0;

  Studio get s => widget.studio;

  Future<void> _publish() async {
    await Busy.run(context, () => StudioService.publish(s),
        success: context.tr('You are live! Share your link.', 'ገጽዎ ተከፍቷል! ሊንክዎን ያጋሩ።'));
  }

  Future<void> _unpublish() async {
    final ok = await confirmDialog(context,
        title: context.tr('Take your page offline?', 'ገጽዎን ከመስመር ውጭ ያድርጉ?'),
        body: context.tr('Clients will not find you or book you until you publish again. Existing bookings stay.',
            'እንደገና እስኪያትሙ ድረስ ደንበኞች አያገኙዎትም። ያሉት ቀጠሮዎች ይቀጥላሉ።'),
        confirm: context.tr('Take offline', 'ከመስመር ውጭ'));
    if (!ok || !mounted) return;
    await Busy.run(context, StudioService.unpublish, success: context.tr('Your page is offline', 'ገጽዎ ተዘግቷል'));
  }

  Future<void> _uploadPrivate(String kind, Map<String, dynamic> files) async {
    PickedMedia? media;
    if (kind == 'work') {
      media = await MediaService.pickVideo();
    } else {
      final list = await MediaService.pickImages(multiple: false);
      media = list.isEmpty ? null : list.first;
    }
    if (media == null || !mounted) return;
    setState(() {
      _uploading = kind;
      _progress = 0;
    });
    try {
      final old = files[kind];
      final path = await MediaService.uploadPrivate(media, kind, onProgress: (f) {
        if (mounted) setState(() => _progress = f);
      });
      await StudioService.saveVerificationFile(kind, path);
      if (old is String && old.isNotEmpty && old != path) await MediaService.deletePrivate(old);
      if (mounted) toast(context, context.tr('Uploaded. Thank you.', 'ተጭኗል። እናመሰግናለን።'));
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    final today = dateKey(addisNow());
    final todays = widget.bookings
        .where((b) => b.date == today && b.status == BookingStatus.confirmed)
        .toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    final requests = widget.bookings.where((b) => b.status == BookingStatus.requested).length;
    final deposits = widget.bookings.where((b) => b.status == BookingStatus.depositSubmitted).length;
    final first = session.profile?.firstName ?? s.name;

    return DeskPage(
      title: context.tr('Hello, $first', 'ሰላም $first'),
      children: [
        if (s.status == 'suspended')
          _Banner(
            icon: Icons.pause_circle_outline,
            color: AppColors.honey,
            text: context.tr(
                'Your studio is paused by the A Studio team. Write to ${AppConfig.supportEmail} to sort it out.',
                'ስቱዲዮዎ በኤ ስቱዲዮ ቡድን ቆሟል። ለመፍታት ወደ ${AppConfig.supportEmail} ይጻፉ።'),
          ),
        if (!(session.user?.emailVerified ?? true)) const _EmailVerifyCard(),
        if (AppConfig.phoneCodes && !(session.profile?.phoneVerified ?? false))
          _Banner(
            icon: Icons.phone_iphone,
            color: AppColors.cocoa,
            text: context.tr('Verify your phone so clients see "Phone verified" on your page.',
                'ደንበኞች "ስልክ የተረጋገጠ" እንዲያዩ ስልክዎን ያረጋግጡ።'),
            action: TextButton(
              onPressed: () async {
                final ok = await showPhoneVerifyDialog(context, session.profile?.phone ?? '');
                if (ok && context.mounted) toast(context, context.tr('Phone verified', 'ስልክ ተረጋግጧል'));
              },
              child: Text(context.tr('Verify', 'አረጋግጥ')),
            ),
          ),
        if (requests > 0 || deposits > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              if (requests > 0)
                _Stat(
                  value: '$requests',
                  label: context.tr('requests waiting for you', 'መልስ የሚጠብቁ ጥያቄዎች'),
                  onTap: () => widget.onOpen('bookings'),
                ),
              if (deposits > 0)
                _Stat(
                  value: '$deposits',
                  label: context.tr('deposits to check', 'የሚረጋገጡ ቅድመ ክፍያዎች'),
                  onTap: () => widget.onOpen('bookings'),
                ),
            ]),
          ),
        if (s.isLive || todays.isNotEmpty)
          DeskCard(
          title: context.tr('Today', 'ዛሬ'),
          children: [
            if (todays.isEmpty)
              Text(context.tr('No confirmed appointments today.', 'ዛሬ የተረጋገጠ ቀጠሮ የለም።'))
            else
              for (final b in todays)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BookingTile(booking: b, asArtist: true),
                ),
          ],
        ),
        if (s.isLive) _LinkCard(studio: s),
        StreamBuilder<List<Look>>(
          stream: _looks,
          builder: (context, looksSnap) => FutureBuilder<PaymentDetails>(
            future: _pay,
            builder: (context, paySnap) => _Checklist(
              studio: s,
              looks: looksSnap.data?.length ?? 0,
              hasPayment: !(paySnap.data?.isEmpty ?? true),
              emailVerified: session.user?.emailVerified ?? false,
              onOpen: widget.onOpen,
              onPublish: _publish,
              onUnpublish: _unpublish,
            ),
          ),
        ),
        if (!s.isLive) _LinkCard(studio: s),
        StreamBuilder<Map<String, dynamic>>(
          stream: _verification,
          builder: (context, snap) => _VerificationCard(
            studio: s,
            files: snap.data ?? const {},
            uploading: _uploading,
            progress: _progress,
            onUpload: (kind) => _uploadPrivate(kind, snap.data ?? const {}),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;
  const _Banner({required this.icon, required this.color, required this.text, this.action});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (action != null) action!,
        ]),
      );
}

class _EmailVerifyCard extends StatelessWidget {
  const _EmailVerifyCard();
  @override
  Widget build(BuildContext context) {
    final email = Session.instance.user?.email ?? '';
    return _Banner(
      icon: Icons.mark_email_unread_outlined,
      color: AppColors.rouge,
      text: context.tr('Confirm your email: we sent a link to $email. Check spam too.',
          'ኢሜይልዎን ያረጋግጡ፡ ወደ $email ሊንክ ልከናል።'),
      action: Wrap(children: [
        TextButton(
          onPressed: () => Busy.run(context, AuthService.resendVerification,
              success: context.tr('Sent again', 'እንደገና ተልኳል')),
          child: Text(context.tr('Resend', 'እንደገና ላክ')),
        ),
        TextButton(
          onPressed: () async {
            final ok = await Busy.run(context, AuthService.refreshEmailVerified);
            if (!context.mounted) return;
            toast(
                context,
                ok == true
                    ? context.tr('Email verified', 'ኢሜይል ተረጋግጧል')
                    : context.tr('Not confirmed yet. Open the link in the email first.',
                        'ገና አልተረጋገጠም። መጀመሪያ በኢሜይሉ ያለውን ሊንክ ይክፈቱ።'));
          },
          child: Text(context.tr("I've confirmed", 'አረጋግጫለሁ')),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;
  const _Stat({required this.value, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.petal, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: displayStyle(36, color: AppColors.rouge)),
            const SizedBox(height: 4),
            Text(label),
          ]),
        ),
      );
}

class _LinkCard extends StatelessWidget {
  final Studio studio;
  const _LinkCard({required this.studio});

  @override
  Widget build(BuildContext context) {
    final link = AppConfig.studioLink(studio.handle);
    final pretty = link.replaceFirst('https://', '');
    final text = context.tr('Book me on A Studio: $link', 'በኤ ስቱዲዮ ቀጠሮ ይያዙ፡ $link');
    return DeskCard(
      title: context.tr('Your studio link', 'የስቱዲዮዎ ሊንክ'),
      children: [
        SelectableText(pretty, style: displayStyle(26, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 6),
        Text(
          context.tr('Put it in your Instagram, TikTok and Telegram bios. Every booking through it lands here.',
              'በኢንስታግራም፣ ቲክቶክ እና ቴሌግራም መግለጫዎ ላይ ያስቀምጡት። በሱ የሚመጣ እያንዳንዱ ቀጠሮ እዚህ ይደርሳል።'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!studio.isLive) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.honey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('Your link starts working when you publish your studio.',
                    'ሊንክዎ የሚሠራው ስቱዲዮዎን ከከፈቱ በኋላ ነው።'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.cocoa),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: () => copyText(context, link, done: context.tr('Link copied', 'ሊንኩ ተቀድቷል')),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(context.tr('Copy link', 'ሊንኩን ቅዳ')),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await bridge.nativeShare(title: studio.name, text: text, url: link);
              if (!ok && context.mounted) await copyText(context, link, done: context.tr('Link copied', 'ሊንኩ ተቀድቷል'));
            },
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(context.tr('Share', 'አጋራ')),
          ),
          OutlinedButton(
            onPressed: () => openExternal('https://wa.me/?text=${Uri.encodeComponent(text)}'),
            child: const Text('WhatsApp'),
          ),
          OutlinedButton(
            onPressed: () => openExternal(
                'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(context.tr('Book me on A Studio', 'በኤ ስቱዲዮ ቀጠሮ ይያዙ'))}'),
            child: const Text('Telegram'),
          ),
          TextButton(
            onPressed: () => context.go('/${studio.handle}'),
            child: Text(context.tr('View page', 'ገጹን ይመልከቱ')),
          ),
        ]),
      ],
    );
  }
}

class _Checklist extends StatelessWidget {
  final Studio studio;
  final int looks;
  final bool hasPayment;
  final bool emailVerified;
  final ValueChanged<String> onOpen;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  const _Checklist({
    required this.studio,
    required this.looks,
    required this.hasPayment,
    required this.emailVerified,
    required this.onOpen,
    required this.onPublish,
    required this.onUnpublish,
  });

  @override
  Widget build(BuildContext context) {
    final s = studio;
    final t = Theme.of(context);
    final steps = launchSteps(s, looks);
    final next = nextLaunchStep(steps);
    final done = steps.where((x) => x.done).length;
    final ready = next == null;
    final optional = <_Item>[
      _Item(s.coverUrl.isNotEmpty, context.tr('Cover photo or reel', 'የሽፋን ፎቶ ወይም ቪዲዮ'),
          context.tr('The big image at the top of your page', 'በገጽዎ አናት ላይ ያለው ትልቅ ምስል'), 'profile'),
      _Item(s.whatsapp.isNotEmpty || s.telegram.isNotEmpty, context.tr('WhatsApp or Telegram', 'ዋትስአፕ ወይም ቴሌግራም'),
          context.tr('So clients can reach you quickly', 'ደንበኞች በፍጥነት እንዲያገኙዎት'), 'profile'),
      if (s.depositPercent > 0)
        _Item(hasPayment, context.tr('Deposit payment details', 'የቅድመ ክፍያ መረጃ'),
            context.tr('Your Telebirr or CBE account for deposits', 'ለቅድመ ክፍያ የቴሌብር ወይም የንግድ ባንክ ሂሳብዎ'), 'payments'),
      _Item(emailVerified, context.tr('Email confirmed', 'ኢሜይል ተረጋግጧል'),
          context.tr('Open the link we emailed you', 'የላክንልዎትን ሊንክ ይክፈቱ'), ''),
    ];

    final shine = DeskCard(
      title: context.tr('Make it shine', 'ያሳምሩት'),
      trailing: Text('${optional.where((i) => i.done).length} / ${optional.length}', style: labelCaps()),
      children: [
        Text(context.tr('Optional, and they help clients choose you.', 'አማራጭ ናቸው፤ ደንበኞች እርስዎን እንዲመርጡ ይረዳሉ።'),
            style: t.textTheme.bodySmall),
        const SizedBox(height: 4),
        for (final i in optional)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(i.done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: i.done ? AppColors.sage : AppColors.taupe),
            title: Text(i.title),
            subtitle: Text(i.subtitle),
            trailing: i.tab.isEmpty ? null : const Icon(Icons.chevron_right),
            onTap: i.tab.isEmpty ? null : () => onOpen(i.tab),
          ),
      ],
    );

    if (s.isLive) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DeskCard(
          title: context.tr('Your page is live', 'ገጽዎ ክፍት ነው'),
          children: [
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pill(context.tr('Live', 'ክፍት'), icon: Icons.circle, background: AppColors.sage, foreground: AppColors.milk),
              TextButton(onPressed: onUnpublish, child: Text(context.tr('Take my page offline', 'ገጼን ዝጋ'))),
            ]),
          ],
        ),
        if (optional.any((i) => !i.done)) shine,
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DeskCard(
        title: ready ? context.tr('Ready to go live', 'ለመክፈት ዝግጁ ነው') : context.tr("Let's get you live", 'ለመክፈት እንዘጋጅ'),
        trailing: Text('$done / ${steps.length}', style: labelCaps()),
        children: [
          Text(ready
              ? context.tr('Everything clients need is here. Publish, and they can find and book you.',
                  'ደንበኞች የሚያስፈልጋቸው ሁሉ ተሟልቷል። ይክፈቱ፤ ያገኙዎታል፣ ቀጠሮም ይይዛሉ።')
              : context.tr('Clients can find and book you once you publish. Finish these four steps first.',
                  'ከከፈቱ በኋላ ደንበኞች ያገኙዎታል፣ ቀጠሮም ይይዛሉ። መጀመሪያ እነዚህን አራት እርምጃዎች ይጨርሱ።')),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: done / steps.length, minHeight: 6),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _StepRow(number: i + 1, step: steps[i], isNext: identical(steps[i], next), onOpen: onOpen),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: ready && s.status != 'suspended' ? onPublish : null,
            icon: const Icon(Icons.rocket_launch_outlined),
            label: Text(context.tr('Publish my studio', 'ስቱዲዮዬን ክፈት')),
          ),
          const SizedBox(height: 8),
          Text(
            ready
                ? context.tr('You go live with a New badge. Our team verifies you in the background.',
                    'በ"አዲስ" ምልክት ይከፈታሉ። ቡድናችን በጎን ያረጋግጥዎታል።')
                : context.tr('The Publish button turns on when all four steps are done.',
                    'አራቱም እርምጃዎች ሲጠናቀቁ «ስቱዲዮዬን ክፈት» ይበራል።'),
            style: t.textTheme.bodySmall,
          ),
        ],
      ),
      shine,
    ]);
  }
}

/// One of the four steps to go live. The next one to do is highlighted
/// and carries its own button.
class _StepRow extends StatelessWidget {
  final int number;
  final LaunchStep step;
  final bool isNext;
  final ValueChanged<String> onOpen;
  const _StepRow({required this.number, required this.step, required this.isNext, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final circle = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: step.done ? AppColors.sage : (isNext ? AppColors.rouge : null),
        border: step.done || isNext ? null : Border.all(color: AppColors.latte, width: 1.5),
      ),
      child: step.done
          ? const Icon(Icons.check, size: 18, color: AppColors.milk)
          : Text('$number',
              style: TextStyle(
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  color: isNext ? AppColors.milk : AppColors.taupe)),
    );
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isNext ? 14 : 10),
      decoration: isNext
          ? BoxDecoration(color: AppColors.petal.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16))
          : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        circle,
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.title(context), style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(step.hint(context), style: t.textTheme.bodySmall),
            if (isNext) ...[
              const SizedBox(height: 10),
              FilledButton(onPressed: () => onOpen(step.tab), child: Text(step.action(context))),
            ],
          ]),
        ),
        if (!isNext) const Icon(Icons.chevron_right, color: AppColors.taupe),
      ]),
    );
    if (isNext) return row;
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: () => onOpen(step.tab), child: row);
  }
}

class _Item {
  final bool done;
  final String title;
  final String subtitle;
  final String tab;
  const _Item(this.done, this.title, this.subtitle, this.tab);
}

class _VerificationCard extends StatelessWidget {
  final Studio studio;
  final Map<String, dynamic> files;
  final String uploading;
  final double progress;
  final ValueChanged<String> onUpload;
  const _VerificationCard({
    required this.studio,
    required this.files,
    required this.uploading,
    required this.progress,
    required this.onUpload,
  });

  bool _has(String k) => files[k] is String && (files[k] as String).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final v = studio.verification;
    final String status;
    final Color color;
    switch (v) {
      case 'verified':
        status = context.tr('Verified. Your badge shows on your page.', 'ተረጋግጧል። ምልክቱ በገጽዎ ላይ ይታያል።');
        color = AppColors.sage;
        break;
      case 'pending':
        status = context.tr('We are checking your studio. Upload the two items below to finish.',
            'ስቱዲዮዎን እያረጋገጥን ነው። ለመጨረስ ከታች ያሉትን ሁለቱን ይጫኑ።');
        color = AppColors.honey;
        break;
      case 'rejected':
        status = context.tr(
            'Not approved yet${studio.verificationNote.isEmpty ? '' : ': ${studio.verificationNote}'}. Update and upload again.',
            'ገና አልጸደቀም${studio.verificationNote.isEmpty ? '' : '፡ ${studio.verificationNote}'}። አስተካክለው እንደገና ይጫኑ።');
        color = AppColors.rouge;
        break;
      default:
        status = context.tr('After you publish, our team verifies your ID and your work.',
            'ካተሙ በኋላ ቡድናችን መታወቂያዎን እና ሥራዎን ያረጋግጣል።');
        color = AppColors.taupe;
    }
    Widget row(String kind, IconData icon, String title, String hint) {
      final busy = uploading == kind;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(_has(kind) ? Icons.check_circle : icon, color: _has(kind) ? AppColors.sage : null),
        title: Text(title),
        subtitle: busy ? LinearProgressIndicator(value: progress > 0 ? progress : null) : Text(hint),
        trailing: v == 'verified'
            ? null
            : OutlinedButton(
                onPressed: uploading.isEmpty ? () => onUpload(kind) : null,
                child: Text(_has(kind) ? context.tr('Replace', 'ቀይር') : context.tr('Upload', 'ጫን')),
              ),
      );
    }

    return DeskCard(
      title: context.tr('Verification', 'ማረጋገጫ'),
      children: [
        Row(children: [
          Icon(Icons.verified_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(status)),
        ]),
        const SizedBox(height: 10),
        row('id', Icons.badge_outlined, context.tr('Kebele ID or Fayda digital ID', 'የቀበሌ መታወቂያ ወይም ፋይዳ'),
            context.tr('A clear photo of the card', 'የካርዱ ግልጽ ፎቶ')),
        row('work', Icons.videocam_outlined, context.tr('A 15-second video of you working', 'ሲሠሩ የሚያሳይ የ15 ሰከንድ ቪዲዮ'),
            context.tr('Shows the work on your page is yours', 'በገጽዎ ያለው ሥራ የእርስዎ መሆኑን ያሳያል')),
        const SizedBox(height: 6),
        Text(
          context.tr(
              'These files go to a private folder that only the A Studio team can open. We delete them within 30 days of our decision.',
              'እነዚህ ፋይሎች የኤ ስቱዲዮ ቡድን ብቻ ወደሚከፍተው የግል ማህደር ይሄዳሉ። ከውሳኔያችን በኋላ በ30 ቀናት ውስጥ እንሰርዛቸዋለን።'),
          style: t.textTheme.bodySmall,
        ),
      ],
    );
  }
}
