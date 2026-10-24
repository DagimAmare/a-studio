import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/catalog.dart';
import '../core/ethiopian.dart';
import '../core/format.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../platform/web_bridge.dart' as bridge;
import '../services/listing_service.dart';
import '../services/session.dart';
import '../services/studio_service.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/brand.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/media_viewer.dart';
import '../widgets/shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<List<Studio>> _studios = StudioService.live();
  late final Stream<List<Look>> _looks = StudioService.trending(limit: 48);
  late final Stream<List<Listing>> _listings = ListingService.active();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    bridge.setDocumentTitle('A Studio · Book makeup, nails and hair artists in Addis Ababa');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _go() {
    final q = _search.text.trim();
    context.go(q.isEmpty ? '/explore' : '/explore?q=${Uri.encodeComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= kWide;
    final am = context.isAm;
    return StreamBuilder<List<Studio>>(
      stream: _studios,
      builder: (context, studioSnap) {
        final studios = studioSnap.data ?? const <Studio>[];
        final liveIds = studios.map((s) => s.uid).toSet();
        final featured = [...studios]
          ..sort((a, b) {
            if (a.featured != b.featured) return a.featured ? -1 : 1;
            final r = b.ratingAvg.compareTo(a.ratingAvg);
            return r != 0 ? r : b.ratingCount.compareTo(a.ratingCount);
          });
        return ListView(
          children: [
            // ---------------------------------------------------- hero
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.milk, Color(0xFFF6E9E4)],
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, wide ? 72 : 40, 20, wide ? 64 : 36),
              child: PageBody(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('ADDIS ABABA · MAKEUP · NAILS · HAIR', 'አዲስ አበባ · ሜካፕ · ጥፍር · ፀጉር'),
                        style: labelCaps()),
                    const SizedBox(height: 18),
                    Text(
                      context.tr("Let's get you ready.", 'እንዘጋጅ።'),
                      style: displayStyle(wide ? 64 : 40, height: 1.05, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        context.tr(
                            'Book trusted makeup, nail and hair artists for your wedding, melse, graduation or a Saturday night. At their studio or at your door.',
                            'ለሠርግ፣ ለመልስ፣ ለምረቃ ወይም ለቅዳሜ ምሽት የታመኑ የሜካፕ፣ የጥፍር እና የፀጉር ባለሙያዎችን ይያዙ። በስቱዲዮአቸው ወይም ቤትዎ ድረስ።'),
                        style: t.textTheme.bodyLarge?.copyWith(color: AppColors.cocoa, fontSize: 17),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _search,
                              onSubmitted: (_) => _go(),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: context.tr('Artist, service or area (e.g. bridal, Bole)',
                                    'ባለሙያ፣ አገልግሎት ወይም አካባቢ'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(onPressed: _go, child: Text(context.tr('Search', 'ፈልግ'))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in kOccasions.take(wide ? 8 : 6))
                          ActionChip(
                            label: Text(o.label(am)),
                            onPressed: () => context.go('/explore?occasion=${o.id}'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const TibebBorder(height: 22),
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GlamBanner(),
                  // ------------------------------------------------ artists
                  SectionHeader(
                    context.tr('Artists to know', 'ሊያውቋቸው የሚገቡ ባለሙያዎች'),
                    kicker: context.tr('Book directly', 'በቀጥታ ይያዙ'),
                    trailing: TextButton(
                      onPressed: () => context.go('/explore'),
                      child: Text(context.tr('See all', 'ሁሉንም ይመልከቱ')),
                    ),
                  ),
                  if (studioSnap.connectionState == ConnectionState.waiting && studios.isEmpty)
                    const Loading()
                  else if (featured.isEmpty)
                    _ArtistCta(first: true)
                  else
                    SizedBox(
                      height: 352,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: featured.length.clamp(0, 12),
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (c, i) => ArtistCard(studio: featured[i]),
                      ),
                    ),
                  // ------------------------------------------------ looks
                  StreamBuilder<List<Look>>(
                    stream: _looks,
                    builder: (context, snap) {
                      final looks = (snap.data ?? const <Look>[])
                          .where((l) => liveIds.contains(l.studioUid))
                          .toList();
                      if (looks.isEmpty) return const SizedBox.shrink();
                      final cross = wide ? 4 : 2;
                      final shown = looks.take(wide ? 12 : 8).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(context.tr('Trending looks', 'ተወዳጅ ገጽታዎች'),
                              kicker: context.tr('Tap a look to book its artist', 'ባለሙያውን ለመያዝ ይንኩ')),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: shown.length,
                            itemBuilder: (c, i) => LookTile(
                              look: shown[i],
                              onTap: () => _openLook(context, shown, i),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // ------------------------------------------------ shop
                  StreamBuilder<List<Listing>>(
                    stream: _listings,
                    builder: (context, snap) {
                      final items = snap.data ?? const <Listing>[];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            context.tr('The Vanity', 'የውበት ሱቅ'),
                            kicker: context.tr('New and pre-loved beauty', 'አዲስ እና ያገለገሉ የውበት እቃዎች'),
                            trailing: TextButton(
                              onPressed: () => context.go('/shop'),
                              child: Text(context.tr('Shop all', 'ሁሉንም ይግዙ')),
                            ),
                          ),
                          if (items.isEmpty)
                            Text(
                              context.tr('Artists are stocking the shelves. Check back soon.',
                                  'ባለሙያዎች መደርደሪያዎቹን እየሞሉ ነው። በቅርቡ ይመለሱ።'),
                              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                            )
                          else
                            SizedBox(
                              height: 330,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: items.length.clamp(0, 12),
                                separatorBuilder: (_, __) => const SizedBox(width: 14),
                                itemBuilder: (c, i) => ListingCard(listing: items[i]),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (featured.isNotEmpty) _ArtistCta(first: false),
                ],
              ),
            ),
            const SiteFooter(),
          ],
        );
      },
    );
  }

  void _openLook(BuildContext context, List<Look> looks, int i) {
    final look = looks[i];
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(look.studioName, style: Theme.of(c).textTheme.headlineSmall),
              if (look.caption.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(look.caption),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(c);
                  openMediaViewer(
                    context,
                    looks.map((l) => MediaItem(l.url, isVideo: l.isVideo, caption: l.studioName)).toList(),
                    i,
                  );
                },
                child: Text(c.tr('View full size', 'በሙሉ መጠን ይመልከቱ')),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.go('/${look.studioHandle}');
                },
                child: Text(c.tr('Book this look', 'ይህንን ገጽታ ይያዙ')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlamBanner extends StatelessWidget {
  const _GlamBanner();

  @override
  Widget build(BuildContext context) {
    final now = addisNow();
    final today = DateTime(now.year, now.month, now.day);
    final events = upcomingGlamEvents(today, days: 45)
        .where((e) => e.kind == 'holiday' || e.kind == 'season')
        .toList();
    if (events.isEmpty) return const SizedBox(height: 8);
    final e = events.first;
    final am = context.isAm;
    final ongoing = !e.start.isAfter(today);
    final days = e.start.difference(today).inDays;
    final name = am ? e.nameAm : e.nameEn;
    final headline = ongoing
        ? context.tr('$name is here', '$name ደርሷል')
        : (days == 1
            ? context.tr('$name is tomorrow', '$name ነገ ነው')
            : context.tr('$name in $days days', '$name በ$days ቀናት ውስጥ'));
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('GLAM CALENDAR', 'የውበት ቀን መቁጠሪያ'),
                    style: labelCaps(color: AppColors.champagne)),
                const SizedBox(height: 8),
                Text(headline, style: displayStyle(28, color: AppColors.milk)),
                const SizedBox(height: 6),
                Text(
                  '${bothDates(e.start, amharic: am)}${e.expected ? context.tr(' · date expected', ' · የሚጠበቅ ቀን') : ''}',
                  style: const TextStyle(fontFamily: 'DMSans', color: AppColors.noirMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.milk, foregroundColor: AppColors.espresso),
            onPressed: () => context.go('/explore'),
            child: Text(context.tr('Book glam', 'ይያዙ')),
          ),
        ],
      ),
    );
  }
}

class _ArtistCta extends StatelessWidget {
  final bool first;
  const _ArtistCta({required this.first});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = Session.instance;
    return Container(
      margin: const EdgeInsets.only(top: 36),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.petal,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('FOR ARTISTS', 'ለባለሙያዎች'), style: labelCaps(color: AppColors.cocoa)),
          const SizedBox(height: 10),
          Text(
            first
                ? context.tr('Be one of the first artists on A Studio.', 'በኤ ስቱዲዮ ከመጀመሪያዎቹ ባለሙያዎች አንዱ ይሁኑ።')
                : context.tr('Your studio, one link.', 'የእርስዎ ስቱዲዮ፣ በአንድ ሊንክ።'),
            style: displayStyle(32, color: AppColors.espresso),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
                'Get your own page with your work, prices, reviews and a Book button. Share it in your bio, take deposits, and stop losing mornings to no-shows.',
                'ሥራዎ፣ ዋጋዎ፣ ግምገማዎችዎ እና የቀጠሮ ቁልፍ ያለበት የራስዎ ገጽ ያግኙ። በባዮዎ ያጋሩት፣ ቅድመ ክፍያ ይቀበሉ።'),
            style: t.textTheme.bodyLarge?.copyWith(color: AppColors.cocoa),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.go(s.signedIn ? '/desk/setup' : '/signup?role=artist'),
            child: Text(context.tr('Get your studio link', 'የስቱዲዮ ሊንክዎን ያግኙ')),
          ),
        ],
      ),
    );
  }
}
