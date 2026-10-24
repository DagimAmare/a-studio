import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/catalog.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../platform/web_bridge.dart' as bridge;
import '../services/listing_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/shell.dart';

/// The Vanity: new products from A Studio and new or pre-loved items from
/// artists, sold through listings with chat contact (no checkout in v1).
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final Stream<List<Listing>> _stream = ListingService.active();
  final _q = TextEditingController();
  String _category = '';
  String _kind = ''; // '' | new | preloved | official
  String _area = '';
  String _sort = 'new';

  @override
  void initState() {
    super.initState();
    bridge.setDocumentTitle('The Vanity · A Studio');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _matches(Listing l) {
    if (_category.isNotEmpty && l.category != _category) return false;
    if (_kind == 'official' && !l.official) return false;
    if (_kind == 'new' && l.isPreLoved) return false;
    if (_kind == 'preloved' && !l.isPreLoved) return false;
    if (_area.isNotEmpty && l.subCity != _area) return false;
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = '${l.title} ${l.brand} ${l.description} ${l.sellerName}'.toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  void _sell() {
    if (!Session.instance.signedIn) {
      context.go('/signin?next=${Uri.encodeComponent('/shop/new')}');
      return;
    }
    context.go('/shop/new');
  }

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kWide;
    final cols = width >= 1100 ? 4 : (width >= 700 ? 3 : 2);
    return StreamBuilder<List<Listing>>(
      stream: _stream,
      builder: (context, snap) {
        final list = (snap.data ?? const <Listing>[]).where(_matches).toList();
        if (_sort == 'low') list.sort((a, b) => a.price.compareTo(b.price));
        if (_sort == 'high') list.sort((a, b) => b.price.compareTo(a.price));
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    context.tr('The Vanity', 'የውበት ሱቅ'),
                    kicker: context.tr('Shop', 'ሱቅ'),
                    trailing: FilledButton.icon(
                      onPressed: _sell,
                      icon: const Icon(Icons.add),
                      label: Text(context.tr('Sell an item', 'እቃ ይሽጡ')),
                    ),
                  ),
                  Text(
                    context.tr('New products from A Studio, and new or pre-loved gear from artists. Message the seller to buy.',
                        'ከኤ ስቱዲዮ አዳዲስ ምርቶች፣ እና ከባለሙያዎች አዲስ ወይም ያገለገሉ እቃዎች። ለመግዛት ለሻጩ መልዕክት ይላኩ።'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(
                      width: wide ? 320 : double.infinity,
                      child: TextField(
                        controller: _q,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: context.tr('Search brand or item', 'ብራንድ ወይም እቃ ይፈልጉ'),
                        ),
                      ),
                    ),
                    for (final k in [
                      ('', context.tr('All', 'ሁሉም')),
                      ('new', context.tr('New', 'አዲስ')),
                      ('preloved', context.tr('Pre-loved', 'ያገለገለ')),
                      ('official', 'A Studio'),
                    ])
                      ChoiceChip(label: Text(k.$2), selected: _kind == k.$1, onSelected: (_) => setState(() => _kind = k.$1)),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(context.tr('Every category', 'ሁሉም ዘርፍ')),
                          selected: _category.isEmpty,
                          onSelected: (_) => setState(() => _category = ''),
                        ),
                      ),
                      for (final c in kListingCategories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.label(am)),
                            selected: _category == c.id,
                            onSelected: (_) => setState(() => _category = _category == c.id ? '' : c.id),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    SizedBox(
                      width: 220,
                      child: SelectField<String>(
                        label: context.tr('Pickup area', 'የመረከቢያ አካባቢ'),
                        value: _area,
                        items: [('', context.tr('Anywhere in Addis', 'በአዲስ አበባ የትም')), for (final c in kSubCities) (c.id, c.label(am))],
                        onChanged: (v) => setState(() => _area = v ?? ''),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: SelectField<String>(
                        label: context.tr('Sort', 'ደርድር'),
                        value: _sort,
                        items: [
                          ('new', context.tr('Newest', 'አዲስ የተለጠፉ')),
                          ('low', context.tr('Price: low to high', 'ዋጋ፡ ከዝቅተኛ')),
                          ('high', context.tr('Price: high to low', 'ዋጋ፡ ከከፍተኛ')),
                        ],
                        onChanged: (v) => setState(() => _sort = v ?? 'new'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  if (snap.hasError)
                    ErrorView(context.tr('Could not load the shop.', 'ሱቁን መጫን አልተቻለም።'))
                  else if (!snap.hasData)
                    const Loading()
                  else if (list.isEmpty)
                    EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: context.tr('Nothing here yet', 'እዚህ ገና ምንም የለም'),
                      body: context.tr('Be the first to list something.', 'የመጀመሪያው ሻጭ ይሁኑ።'),
                      action: FilledButton(onPressed: _sell, child: Text(context.tr('Sell an item', 'እቃ ይሽጡ'))),
                    )
                  else
                    LayoutBuilder(builder: (context, c) {
                      final w = (c.maxWidth - (cols - 1) * 12) / cols;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        for (final l in list) ListingCard(listing: l, width: w),
                      ]);
                    }),
                  const SizedBox(height: 24),
                  Text(context.tr('HOUSE RULES', 'የሱቁ ሕጎች'), style: labelCaps()),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                        'No opened mascara, lip products, foundation, eyeliner or skincare; no used lashes or sponges; nothing expired, counterfeit, or containing mercury. A Studio does not handle payment or delivery for The Vanity: meet in a safe public place and check seals and expiry dates before you pay.',
                        'የተከፈቱ ማስካራ፣ የከንፈር ምርቶች፣ ፋውንዴሽን፣ አይላይነር ወይም የቆዳ ምርቶች፤ ያገለገሉ ሽፋሽፍቶች ወይም ስፖንጆች፤ ጊዜ ያለፈባቸው፣ ሐሰተኛ ወይም ሜርኩሪ ያላቸው ምርቶች አይፈቀዱም። ኤ ስቱዲዮ ለሱቁ ክፍያ ወይም ማድረስ አያስተናግድም፤ ከመክፈልዎ በፊት ደህንነቱ በተጠበቀ ቦታ ተገናኝተው ማሸጊያውን እና የአገልግሎት ጊዜውን ያረጋግጡ።'),
                    style: Theme.of(context).textTheme.bodySmall,
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
