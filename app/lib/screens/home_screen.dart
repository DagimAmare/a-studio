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
import 'desk/desk_launch.dart';

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
                  const _YourStudioCard(),
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

/// For signed-in people: a way into opening a studio, or back to finishing
/// one. Clients can hide it; artists see it until their studio is live.
class _YourStudioCard extends StatefulWidget {
  const _YourStudioCard();
  @override
  State<_YourStudioCard> createState() => _YourStudioCardState();
}

class _YourStudioCardState extends State<_YourStudioCard> {
  static const _hideKey = 'astudio.hideStudioCard';
  bool _hidden = bridge.readLocal(_hideKey) == '1';
  String _looksFor = '';
  Stream<List<Look>>? _looks;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final s = Session.instance;
        if (!s.signedIn || s.profile == null || !s.studioLoaded) return const SizedBox.shrink();
        final studio = s.studio;
        if (studio == null) {
          final artist = s.isArtist;
          if (!artist && _hidden) return const SizedBox.shrink();
          return _frame(
            context,
            kicker: artist ? context.tr('YOUR STUDIO', 'ስቱዲዮዎ') : context.tr('FOR ARTISTS', 'ለባለሙያዎች'),
            title: artist
                ? context.tr('Your studio is waiting', 'ስቱዲዮዎ እየጠበቀዎት ነው')
                : context.tr('Do you do makeup, nails or hair?', 'ሜካፕ፣ ጥፍር ወይም ፀጉር ይሠራሉ?'),
            body: artist
                ? context.tr('Open it in about 10 minutes: your page, your link and your bookings. You can finish the details later.',
                    'በ10 ደቂቃ ያህል ይክፈቱት፡ የራስዎ ገጽ፣ ሊንክ እና ቀጠሮዎች። ዝርዝሩን በኋላ መጨረስ ይችላሉ።')
                : context.tr('Open your own studio for free: your page and link, bookings with deposits, and reviews.',
                    'የራስዎን ስቱዲዮ በነጻ ይክፈቱ፡ የራስዎ ገጽ እና ሊንክ፣ ቅድመ ክፍያ ያላቸው ቀጠሮዎች እና ግምገማዎች።'),
            action: artist ? context.tr('Set up my studio', 'ስቱዲዮዬን አዘጋጅ') : context.tr('Open my studio', 'ስቱዲዮዬን አዘጋጅ'),
            onAction: () => context.go('/desk/setup'),
            onClose: artist
                ? null
                : () {
                    bridge.writeLocal(_hideKey, '1');
                    setState(() => _hidden = true);
                  },
          );
        }
        if (studio.isLive || studio.status == 'suspended') return const SizedBox.shrink();
        if (_looksFor != studio.uid) {
          _looksFor = studio.uid;
          _looks = StudioService.looksFor(studio.uid);
        }
        return StreamBuilder<List<Look>>(
          stream: _looks,
          builder: (context, snap) {
            final steps = launchSteps(studio, snap.data?.length ?? 0);
            final next = nextLaunchStep(steps);
            final done = steps.where((x) => x.done).length;
            return _frame(
              context,
              kicker: context.tr('ALMOST THERE', 'ሊጨርሱ ነው'),
              title: next == null
                  ? context.tr('Your studio is ready to publish', 'ስቱዲዮዎ ለመከፈት ዝግጁ ነው')
                  : context.tr('Finish your studio', 'ስቱዲዮዎን ይጨርሱ'),
              body: next == null
                  ? context.tr('Publish it, and clients can find and book you.', 'ይክፈቱት፤ ደንበኞች ያገኙዎታል፣ ቀጠሮም ይይዛሉ።')
                  : context.tr('$done of ${steps.length} steps done. Next: ${next.title(context)}. Clients can book you once you publish.',
                      'ከ${steps.length} እርምጃዎች $done ተጠናቀዋል። ቀጣዩ፡ ${next.title(context)}። ከከፈቱ በኋላ ደንበኞች ይይዙዎታል።'),
              progress: done / steps.length,
              action: next == null ? context.tr('Publish my studio', 'ስቱዲዮዬን ክፈት') : context.tr('Continue', 'ቀጥል'),
              onAction: () => context.go('/desk'),
            );
          },
        );
      },
    );
  }

  Widget _frame(
    BuildContext context, {
    required String kicker,
    required String title,
    required String body,
    required String action,
    required VoidCallback onAction,
    double? progress,
    VoidCallback? onClose,
  }) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(22, 20, 12, 22),
      decoration: BoxDecoration(color: AppColors.petal, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(kicker, style: labelCaps(color: AppColors.cocoa))),
          if (onClose != null)
            IconButton(
              tooltip: context.tr('Hide', 'ደብቅ'),
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20, color: AppColors.cocoa),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(title, style: displayStyle(26, color: AppColors.espresso)),
            const SizedBox(height: 8),
            Text(body, style: t.textTheme.bodyLarge?.copyWith(color: AppColors.cocoa)),
            if (progress != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.milk,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action)),
          ]),
        ),
      ]),
    );
  }
}
