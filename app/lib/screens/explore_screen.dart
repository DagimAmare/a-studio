import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../platform/web_bridge.dart' as bridge;
import '../services/studio_service.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/shell.dart';

class ExploreScreen extends StatefulWidget {
  final String initialQuery;
  final String initialService;
  final String initialOccasion;
  const ExploreScreen({
    super.key,
    this.initialQuery = '',
    this.initialService = '',
    this.initialOccasion = '',
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final Stream<List<Studio>> _studios = StudioService.live();
  late final TextEditingController _q = TextEditingController(text: widget.initialQuery);
  late String _service = widget.initialService;
  String _area = '';
  bool _homeVisits = false;
  bool _verified = false;
  String _sort = 'top';

  @override
  void initState() {
    super.initState();
    bridge.setDocumentTitle('Explore artists · A Studio');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _matches(Studio s) {
    if (_service.isNotEmpty && !s.specialties.contains(_service)) return false;
    if (_area.isNotEmpty && !s.subCities.contains(_area)) return false;
    if (_homeVisits && !s.homeVisits) return false;
    if (_verified && !s.isVerified) return false;
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      s.name,
      s.handle,
      s.tagline,
      s.bio,
      s.studioArea,
      ...s.services.map((x) => x.name),
      ...s.specialties.map((c) => optionById(kServiceCategories, c).en),
      ...s.specialties.map((c) => optionById(kServiceCategories, c).am),
      ...s.subCities.map((c) => optionById(kSubCities, c).en),
      ...s.subCities.map((c) => optionById(kSubCities, c).am),
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kWide;
    return StreamBuilder<List<Studio>>(
      stream: _studios,
      builder: (context, snap) {
        final all = snap.data ?? const <Studio>[];
        final list = all.where(_matches).toList();
        list.sort((a, b) {
          switch (_sort) {
            case 'new':
              return (b.publishedAt ?? DateTime(2000)).compareTo(a.publishedAt ?? DateTime(2000));
            case 'price':
              return (a.fromPrice ?? 1 << 30).compareTo(b.fromPrice ?? 1 << 30);
          }
          if (a.featured != b.featured) return a.featured ? -1 : 1;
          final r = b.ratingAvg.compareTo(a.ratingAvg);
          return r != 0 ? r : b.ratingCount.compareTo(a.ratingCount);
        });
        final cols = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(context.tr('Find your artist', 'ባለሙያዎን ያግኙ'),
                      kicker: context.tr('Explore', 'ያስሱ')),
                  TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: context.tr('Search by name, service or area', 'በስም፣ በአገልግሎት ወይም በአካባቢ ይፈልጉ'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(context.tr('All services', 'ሁሉም')),
                          selected: _service.isEmpty,
                          onSelected: (_) => setState(() => _service = ''),
                        ),
                        for (final c in kServiceCategories)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(c.label(am)),
                              selected: _service == c.id,
                              onSelected: (v) => setState(() => _service = v ? c.id : ''),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: wide ? 240 : 200,
                        child: SelectField<String>(
                          label: context.tr('Area', 'አካባቢ'),
                          value: _area,
                          items: [
                            ('', context.tr('All of Addis', 'መላው አዲስ አበባ')),
                            for (final c in kSubCities) (c.id, c.label(am)),
                          ],
                          onChanged: (v) => setState(() => _area = v ?? ''),
                        ),
                      ),
                      FilterChip(
                        label: Text(context.tr('Home visits', 'ቤት ድረስ')),
                        selected: _homeVisits,
                        onSelected: (v) => setState(() => _homeVisits = v),
                      ),
                      FilterChip(
                        label: Text(context.tr('Verified', 'የተረጋገጠ')),
                        selected: _verified,
                        onSelected: (v) => setState(() => _verified = v),
                      ),
                      SizedBox(
                        width: 190,
                        child: SelectField<String>(
                          label: context.tr('Sort', 'ደርድር'),
                          value: _sort,
                          items: [
                            ('top', context.tr('Top rated', 'ከፍተኛ ደረጃ')),
                            ('new', context.tr('Newest', 'አዲስ')),
                            ('price', context.tr('Lowest price', 'ዝቅተኛ ዋጋ')),
                          ],
                          onChanged: (v) => setState(() => _sort = v ?? 'top'),
                        ),
                      ),
                    ],
                  ),
                  if (widget.initialOccasion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        context.tr(
                            'Showing artists for ${optionById(kOccasions, widget.initialOccasion).en}. Check each artist\'s looks for that occasion.',
                            'ለ${optionById(kOccasions, widget.initialOccasion).am} ባለሙያዎች።'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (snap.connectionState == ConnectionState.waiting && all.isEmpty)
                    const Loading()
                  else if (list.isEmpty)
                    EmptyState(
                      icon: Icons.brush_outlined,
                      title: context.tr('No artists match yet', 'እስካሁን የሚመሳሰል ባለሙያ የለም'),
                      body: context.tr('Try fewer filters. New artists join every week.',
                          'ማጣሪያዎችን ይቀንሱ። አዳዲስ ባለሙያዎች በየሳምንቱ ይቀላቀላሉ።'),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        final w = (c.maxWidth - (cols - 1) * 16) / cols;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [for (final s in list) ArtistCard(studio: s, width: w)],
                        );
                      },
                    ),
                ],
              ),
            ),
            const SiteFooter(),
          ],
        );
      },
    );
  }
}
