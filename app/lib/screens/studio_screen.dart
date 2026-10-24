import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/validators.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../platform/web_bridge.dart' as bridge;
import '../services/listing_service.dart';
import '../services/report_service.dart';
import '../services/review_service.dart';
import '../services/session.dart';
import '../services/studio_service.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/brand.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/media_viewer.dart';
import '../widgets/shell.dart';
import '../widgets/video_view.dart';
import 'setup_needed_screen.dart';

/// Loads a studio by its handle and keeps it live.
class StudioLoader extends StatefulWidget {
  final String handle;
  final Widget Function(BuildContext context, Studio studio) builder;
  const StudioLoader({super.key, required this.handle, required this.builder});

  @override
  State<StudioLoader> createState() => _StudioLoaderState();
}

class _StudioLoaderState extends State<StudioLoader> {
  late Future<String?> _uid = StudioService.uidForHandle(widget.handle);
  Stream<Studio?>? _stream;
  String? _forUid;

  @override
  void didUpdateWidget(covariant StudioLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      _uid = StudioService.uidForHandle(widget.handle);
      _stream = null;
      _forUid = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _uid,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Loading();
        final uid = snap.data;
        if (uid == null) return const NotFoundView();
        if (_forUid != uid) {
          _forUid = uid;
          _stream = StudioService.watch(uid);
        }
        return StreamBuilder<Studio?>(
          stream: _stream,
          builder: (context, s) {
            if (s.hasError) {
              return EmptyState(
                icon: Icons.lock_clock_outlined,
                title: context.tr('This studio is not open yet', 'ይህ ስቱዲዮ ገና አልተከፈተም'),
                body: context.tr('Check back soon.', 'በቅርቡ ይመለሱ።'),
              );
            }
            if (!s.hasData) return const Loading();
            final studio = s.data;
            if (studio == null) return const NotFoundView();
            return widget.builder(context, studio);
          },
        );
      },
    );
  }
}

class StudioScreen extends StatelessWidget {
  final String handle;
  const StudioScreen({super.key, required this.handle});

  @override
  Widget build(BuildContext context) {
    return StudioLoader(
      handle: handle,
      builder: (context, studio) {
        final theme = buildAppTheme(
          palette: paletteById(studio.decor.theme),
          accent: accentById(studio.decor.accent),
          font: fontById(studio.decor.font),
        );
        return Theme(
          data: theme,
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: _StudioPage(studio: studio),
          ),
        );
      },
    );
  }
}

class _StudioPage extends StatefulWidget {
  final Studio studio;
  const _StudioPage({required this.studio});
  @override
  State<_StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<_StudioPage> {
  late final Stream<List<Look>> _looks = StudioService.looksFor(widget.studio.uid);
  late final Stream<List<Review>> _reviews = ReviewService.forStudio(widget.studio.uid);
  late final Stream<List<Listing>> _listings = ListingService.activeBySeller(widget.studio.uid);
  String _occasion = '';

  Studio get s => widget.studio;

  @override
  void initState() {
    super.initState();
    bridge.setDocumentTitle('${widget.studio.name} · A Studio');
  }

  Future<void> _share() async {
    final link = AppConfig.studioLink(s.handle);
    final ok = await bridge.nativeShare(
        title: s.name, text: '${s.name} on A Studio', url: link);
    if (!ok && mounted) await copyText(context, link, done: context.tr('Link copied', 'ሊንኩ ተቀድቷል'));
  }

  void _message() {
    final me = Session.instance;
    if (!me.signedIn) {
      context.go('/signin?next=${Uri.encodeComponent('/${s.handle}')}');
      return;
    }
    context.go('/message/${s.uid}?name=${Uri.encodeComponent(s.name)}&photo=${Uri.encodeComponent(s.avatarUrl)}');
  }

  Future<void> _report() async {
    if (!Session.instance.signedIn) {
      context.go('/signin?next=${Uri.encodeComponent('/${s.handle}')}');
      return;
    }
    final reason = await textPrompt(context,
        title: context.tr('Report this studio', 'ይህንን ስቱዲዮ ሪፖርት ያድርጉ'),
        hint: context.tr('What is wrong? (fake work, rude behaviour, scam...)',
            'ችግሩ ምንድን ነው?'),
        required: true,
        confirm: context.tr('Send report', 'ሪፖርት ላክ'));
    if (reason == null || !mounted) return;
    await Busy.run(context, () => ReportService.report(
          targetType: 'studio',
          targetId: s.uid,
          targetLabel: '@${s.handle}',
          reason: reason,
        ), success: context.tr('Thank you. Our team will look at it.', 'እናመሰግናለን። ቡድናችን ይመለከተዋል።'));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= kWide;
    final am = context.isAm;
    final me = Session.instance;
    final isOwner = me.uid == s.uid;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (isOwner)
          Container(
            color: AppColors.espresso,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Text(
                  s.isLive
                      ? context.tr('This is your live studio page.', 'ይህ የቀጥታ ስቱዲዮ ገጽዎ ነው።')
                      : context.tr('Preview: your studio is not published yet.', 'ቅድመ እይታ፡ ስቱዲዮዎ ገና አልታተመም።'),
                  style: const TextStyle(fontFamily: 'DMSans', color: AppColors.milk),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/desk'),
                style: TextButton.styleFrom(foregroundColor: AppColors.champagne),
                child: Text(context.tr('Open Studio Desk', 'ዴስኩን ይክፈቱ')),
              ),
            ]),
          ),
        // ------------------------------------------------------- hero
        SizedBox(
          height: wide ? 440 : 320,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (s.coverUrl.isEmpty)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.petal, AppColors.latte],
                    ),
                  ),
                )
              else if (s.coverType == 'video')
                WebVideo(s.coverUrl, autoplay: true, muted: true, loop: true, controls: false, cover: true)
              else
                NetImage(s.coverUrl),
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.noir.withValues(alpha: 0.72)],
                      stops: const [0.35, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: PageBody(
                  maxWidth: 980,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.milk, width: 3),
                        ),
                        child: Avatar(url: s.avatarUrl, name: s.name, size: wide ? 96 : 72),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              if (s.isVerified)
                                Pill(context.tr('Verified', 'የተረጋገጠ'),
                                    icon: Icons.verified_outlined, background: AppColors.milk),
                              if (!s.isVerified && s.isNew)
                                Pill(context.tr('New on A Studio', 'በኤ ስቱዲዮ አዲስ'), background: AppColors.milk),
                              for (final b in s.badges) Pill(_badgeLabel(context, b), background: AppColors.champagne),
                            ]),
                            const SizedBox(height: 8),
                            Text(s.name,
                                style: t.textTheme.displaySmall?.copyWith(
                                    color: AppColors.milk, fontSize: wide ? 46 : 32)),
                            if (s.tagline.isNotEmpty)
                              Text(s.tagline,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'DMSans', color: AppColors.noirText, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        PageBody(
          maxWidth: 980,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (s.ratingCount > 0)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      RatingStars(s.ratingAvg),
                      const SizedBox(width: 6),
                      Text('${s.ratingAvg.toStringAsFixed(1)} · ${s.ratingCount} ${context.tr('reviews', 'ግምገማዎች')}',
                          style: t.textTheme.labelMedium),
                    ]),
                  if (s.subCities.isNotEmpty)
                    _Fact(Icons.place_outlined,
                        s.subCities.map((c) => optionById(kSubCities, c).label(am)).join(', ')),
                  if (s.atStudio) _Fact(Icons.storefront_outlined, context.tr('Studio', 'ስቱዲዮ')),
                  if (s.homeVisits) _Fact(Icons.home_outlined, context.tr('Home visits', 'ቤት ድረስ')),
                  if (s.venueVisits) _Fact(Icons.celebration_outlined, context.tr('Venues', 'የዝግጅት ቦታ')),
                  if (s.emailVerified) _Fact(Icons.mark_email_read_outlined, context.tr('Email verified', 'ኢሜይል የተረጋገጠ')),
                  if (s.phoneVerified) _Fact(Icons.phone_iphone, context.tr('Phone verified', 'ስልክ የተረጋገጠ')),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: s.isLive || isOwner ? () => context.go('/book/${s.handle}') : null,
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(context.tr('Book now', 'ቀጠሮ ይያዙ')),
                  ),
                  OutlinedButton.icon(
                    onPressed: isOwner ? null : _message,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(context.tr('Message', 'መልዕክት')),
                  ),
                  if (s.whatsapp.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => openExternal(
                          'https://wa.me/${whatsappDigits(s.whatsapp)}?text=${Uri.encodeComponent('Selam ${s.name}, I found you on A Studio.')}'),
                      icon: const Icon(Icons.phone_in_talk_outlined),
                      label: const Text('WhatsApp'),
                    ),
                  if (s.telegram.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => openExternal('https://t.me/${telegramUsername(s.telegram)}'),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Telegram'),
                    ),
                  IconButton.outlined(
                    tooltip: context.tr('Share', 'አጋራ'),
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share),
                  ),
                ],
              ),
              // ------------------------------------------------- services
              SectionHeader(context.tr('Services', 'አገልግሎቶች'), kicker: context.tr('Menu', 'ዝርዝር')),
              if (s.activeServices.isEmpty)
                Text(context.tr('Services are coming soon.', 'አገልግሎቶች በቅርቡ ይቀርባሉ።'))
              else
                ...s.activeServices.map((svc) => _ServiceRow(studio: s, service: svc)),
              // ------------------------------------------------- portfolio
              StreamBuilder<List<Look>>(
                stream: _looks,
                builder: (context, snap) {
                  final looks = snap.data ?? const <Look>[];
                  if (looks.isEmpty) return const SizedBox.shrink();
                  final occasions = looks.map((l) => l.occasion).where((o) => o.isNotEmpty).toSet().toList();
                  final shown = _occasion.isEmpty ? looks : looks.where((l) => l.occasion == _occasion).toList();
                  final cols = MediaQuery.sizeOf(context).width >= 700 ? 4 : 3;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(context.tr('Portfolio', 'የሥራ ማሳያ'),
                          kicker: '${looks.length} ${context.tr('looks', 'ገጽታዎች')}'),
                      if (occasions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            ChoiceChip(
                              label: Text(context.tr('All', 'ሁሉም')),
                              selected: _occasion.isEmpty,
                              onSelected: (_) => setState(() => _occasion = ''),
                            ),
                            for (final o in occasions)
                              ChoiceChip(
                                label: Text(optionById(kOccasions, o).label(am)),
                                selected: _occasion == o,
                                onSelected: (v) => setState(() => _occasion = v ? o : ''),
                              ),
                          ]),
                        ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: shown.length,
                        itemBuilder: (c, i) => LookTile(
                          look: shown[i],
                          showArtist: false,
                          onTap: () => openMediaViewer(
                            context,
                            shown.map((l) => MediaItem(l.url, isVideo: l.isVideo, caption: l.caption)).toList(),
                            i,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // ------------------------------------------------- reviews
              StreamBuilder<List<Review>>(
                stream: _reviews,
                builder: (context, snap) {
                  final reviews = snap.data ?? const <Review>[];
                  final (avg, count) = ReviewService.summarize(reviews);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(context.tr('Reviews', 'ግምገማዎች'),
                          kicker: count == 0
                              ? context.tr('From real bookings only', 'ከእውነተኛ ቀጠሮዎች ብቻ')
                              : '${avg.toStringAsFixed(1)} · $count'),
                      if (reviews.isEmpty)
                        Text(
                            context.tr('No reviews yet. Reviews come only from completed A Studio bookings.',
                                'እስካሁን ግምገማ የለም። ግምገማዎች የሚመጡት ከተጠናቀቁ ቀጠሮዎች ብቻ ነው።'),
                            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant))
                      else ...[
                        Wrap(spacing: 18, runSpacing: 6, children: [
                          _SubScore(context.tr('Skill', 'ክህሎት'), reviews.map((r) => r.skill)),
                          _SubScore(context.tr('Punctuality', 'ሰዓት አክባሪነት'), reviews.map((r) => r.punctuality)),
                          _SubScore(context.tr('Hygiene', 'ንጽሕና'), reviews.map((r) => r.hygiene)),
                          _SubScore(context.tr('Value', 'ዋጋ'), reviews.map((r) => r.value)),
                        ]),
                        const SizedBox(height: 12),
                        ...reviews.take(20).map((r) => _ReviewCard(review: r)),
                      ],
                    ],
                  );
                },
              ),
              // ------------------------------------------------- about
              SectionHeader(context.tr('About and policies', 'ስለ እና ደንቦች')),
              if (s.bio.isNotEmpty) ...[
                Text(s.bio, style: t.textTheme.bodyLarge),
                const SizedBox(height: 14),
              ],
              _PolicyLine(Icons.payments_outlined,
                  s.depositPercent == 0
                      ? context.tr('No deposit needed.', 'ቅድመ ክፍያ አያስፈልግም።')
                      : context.tr('${s.depositPercent}% deposit to confirm, paid by Telebirr or CBE.',
                          'ለማረጋገጥ ${s.depositPercent}% ቅድመ ክፍያ በቴሌብር ወይም በንግድ ባንክ።')),
              _PolicyLine(Icons.event_busy_outlined,
                  am ? policyById(s.cancellationPolicy).detailAm : policyById(s.cancellationPolicy).detailEn),
              if (s.homeVisits || s.venueVisits)
                _PolicyLine(
                    Icons.directions_car_outlined,
                    s.travelFee > 0
                        ? context.tr('Travel fee for home and venue visits: ${birr(s.travelFee)}.',
                            'ለቤት እና ለዝግጅት ቦታ የትራንስፖርት ክፍያ፡ ${birr(s.travelFee)}።')
                        : context.tr('No travel fee for home visits.', 'ለቤት ጉብኝት የትራንስፖርት ክፍያ የለም።')),
              _PolicyLine(Icons.schedule_outlined,
                  context.tr('Book at least ${s.noticeHours} hours ahead.', 'ቢያንስ ከ${s.noticeHours} ሰዓት በፊት ይያዙ።')),
              if (s.studioArea.isNotEmpty) _PolicyLine(Icons.place_outlined, s.studioArea),
              // ------------------------------------------------- shop
              StreamBuilder<List<Listing>>(
                stream: _listings,
                builder: (context, snap) {
                  final items = (snap.data ?? const <Listing>[]).where((l) => l.status == 'active').toList();
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(context.tr('From ${s.name}\'s vanity', 'ከ${s.name} ሱቅ')),
                      SizedBox(
                        height: 330,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (c, i) => ListingCard(listing: items[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              const TibebBorder(height: 20),
              const SizedBox(height: 10),
              Row(children: [
                Text('astudio.hepius.co/${s.handle}', style: t.textTheme.bodySmall),
                const Spacer(),
                if (!isOwner)
                  TextButton(onPressed: _report, child: Text(context.tr('Report', 'ሪፖርት'))),
              ]),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  String _badgeLabel(BuildContext context, String id) {
    switch (id) {
      case 'top_rated':
        return context.tr('Top rated', 'ከፍተኛ ደረጃ');
      case 'bridal':
        return context.tr('Bridal specialist', 'የሙሽራ ባለሙያ');
      case 'fast':
        return context.tr('Fast responder', 'ፈጣን መላሽ');
      case 'certified':
        return context.tr('A Studio Certified', 'የኤ ስቱዲዮ ማረጋገጫ');
    }
    return id;
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.labelMedium),
      ]);
}

class _PolicyLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PolicyLine(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

String priceLabel(BuildContext context, ServiceItem svc) {
  if (svc.priceHidden || svc.price <= 0) return context.tr('Price on request', 'ዋጋ በጥያቄ');
  return svc.priceFrom ? '${context.tr('from', 'ከ')} ${birr(svc.price)}' : birr(svc.price);
}

class _ServiceRow extends StatelessWidget {
  final Studio studio;
  final ServiceItem service;
  const _ServiceRow({required this.studio, required this.service});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(service.name, style: t.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${durationLabel(service.durationMin)} · ${priceLabel(context, service)}',
                  style: t.textTheme.bodySmall,
                ),
                if (service.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(service.description, style: t.textTheme.bodyMedium),
                ],
              ]),
            ),
            TextButton(
              onPressed: () => context.go('/book/${studio.handle}?service=${service.id}'),
              child: Text(context.tr('Book', 'ይያዙ')),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SubScore extends StatelessWidget {
  final String label;
  final Iterable<int> values;
  const _SubScore(this.label, this.values);
  @override
  Widget build(BuildContext context) {
    final list = values.toList();
    final avg = list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
    return Text('$label ${avg.toStringAsFixed(1)}', style: Theme.of(context).textTheme.labelMedium);
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              RatingStars(review.rating.toDouble()),
              const SizedBox(width: 8),
              Text(review.clientName, style: t.textTheme.labelMedium),
              const Spacer(),
              Text(timeAgo(review.createdAt), style: t.textTheme.bodySmall),
            ]),
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.text, style: t.textTheme.bodyMedium),
            ],
            if (review.reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('${context.tr('Reply', 'መልስ')}: ${review.reply}', style: t.textTheme.bodySmall),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
