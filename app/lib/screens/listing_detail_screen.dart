import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/validators.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../platform/web_bridge.dart' as bridge;
import '../services/admin_service.dart';
import '../services/listing_service.dart';
import '../services/report_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/common.dart';
import '../widgets/media_viewer.dart';
import '../widgets/shell.dart';

class ListingDetailScreen extends StatefulWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});
  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late final Stream<Listing?> _stream = ListingService.watch(widget.id);
  final _pages = PageController();
  int _photo = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String _link(Listing l) => '${AppConfig.productionUrl}/shop/${l.id}';

  void _message(Listing l) {
    if (!Session.instance.signedIn) {
      context.go('/signin?next=${Uri.encodeComponent('/shop/${l.id}')}');
      return;
    }
    final q = Uri(queryParameters: {
      'name': l.sellerName,
      'kind': 'listing',
      'ref': l.id,
      'title': '${l.title} · ${birr(l.price)}',
      'link': '/shop/${l.id}',
    }).query;
    context.go('/message/${l.sellerUid}?$q');
  }

  Future<void> _report(Listing l) async {
    if (!Session.instance.signedIn) {
      context.go('/signin?next=${Uri.encodeComponent('/shop/${l.id}')}');
      return;
    }
    final reason = await textPrompt(context,
        title: context.tr('Report this listing', 'ይህን እቃ ሪፖርት ያድርጉ'),
        hint: context.tr('Counterfeit, opened product, expired, scam...', 'ሐሰተኛ፣ የተከፈተ፣ ጊዜው ያለፈበት...'),
        required: true,
        confirm: context.tr('Send report', 'ሪፖርት ላክ'));
    if (reason == null || !mounted) return;
    await Busy.run(context,
        () => ReportService.report(targetType: 'listing', targetId: l.id, targetLabel: l.title, reason: reason),
        success: context.tr('Thank you. Our team will look at it.', 'እናመሰግናለን። ቡድናችን ይመለከተዋል።'));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Listing?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: context.tr('This item is no longer available', 'ይህ እቃ ከአሁን በኋላ የለም'),
            action: FilledButton(onPressed: () => context.go('/shop'), child: Text(context.tr('Back to the shop', 'ወደ ሱቁ ተመለስ'))),
          );
        }
        if (!snap.hasData) return const Loading();
        final l = snap.data;
        if (l == null) {
          return EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: context.tr('This item is no longer available', 'ይህ እቃ ከአሁን በኋላ የለም'),
            action: FilledButton(onPressed: () => context.go('/shop'), child: Text(context.tr('Back to the shop', 'ወደ ሱቁ ተመለስ'))),
          );
        }
        bridge.setDocumentTitle('${l.title} · The Vanity');
        return _body(context, l);
      },
    );
  }

  Widget _body(BuildContext context, Listing l) {
    final t = Theme.of(context);
    final am = context.isAm;
    final me = Session.instance;
    final owner = me.uid == l.sellerUid;
    final wide = MediaQuery.sizeOf(context).width >= kWide;
    final photos = l.photos;
    final expiry = l.expiry.isEmpty ? null : DateTime.tryParse('${l.expiry}-01');
    final now = DateTime.now();
    final expired = expiry != null && DateTime(expiry.year, expiry.month + 1, 1).isBefore(now);
    final expiringSoon = expiry != null && !expired && expiry.isBefore(DateTime(now.year, now.month + 3, now.day));

    final gallery = Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1,
          child: photos.isEmpty
              ? Container(color: AppColors.oat, child: const Icon(Icons.image_outlined, color: AppColors.latte, size: 48))
              : PageView.builder(
                  controller: _pages,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _photo = i),
                  itemBuilder: (c, i) => GestureDetector(
                    onTap: () => openMediaViewer(context, [for (final p in photos) MediaItem(p)], i),
                    child: NetImage(photos[i]),
                  ),
                ),
        ),
      ),
      if (photos.length > 1) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (c, i) => GestureDetector(
              onTap: () => _pages.animateToPage(i, duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: i == _photo ? AppColors.espresso : Colors.transparent, width: 2),
                ),
                child: NetImage(photos[i], width: 60, height: 60, radius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ],
    ]);

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (l.official) const Pill('A Studio', background: AppColors.espresso, foreground: AppColors.milk),
          Pill(optionById(kConditions, l.condition).label(am)),
          Pill(optionById(kListingCategories, l.category).label(am), background: AppColors.oat),
          if (l.status == 'sold') Pill(context.tr('Sold', 'ተሽጧል'), background: AppColors.taupe, foreground: AppColors.milk),
          if (l.status == 'removed') Pill(context.tr('Removed', 'ተወግዷል'), background: AppColors.rouge, foreground: AppColors.milk),
        ]),
        const SizedBox(height: 12),
        Text(l.title, style: t.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Row(children: [
          Text(birr(l.price), style: displayStyle(30, color: t.colorScheme.onSurface)),
          const SizedBox(width: 10),
          if (l.negotiable) Text(context.tr('Negotiable', 'ድርድር አለው'), style: t.textTheme.bodySmall),
        ]),
        const SizedBox(height: 14),
        if (l.brand.isNotEmpty) _Fact(context.tr('Brand', 'ብራንድ'), l.brand),
        if (l.quantity > 1) _Fact(context.tr('Quantity', 'ብዛት'), '${l.quantity}'),
        if (l.subCity.isNotEmpty) _Fact(context.tr('Pickup', 'መረከቢያ'), optionById(kSubCities, l.subCity).label(am)),
        if (expiry != null)
          _Fact(
            context.tr('Expiry', 'የአገልግሎት ጊዜ'),
            '${l.expiry}${expired ? context.tr(' (expired)', ' (አልፏል)') : (expiringSoon ? context.tr(' (within 3 months)', ' (በ3 ወር ውስጥ)') : '')}',
            warn: expired || expiringSoon,
          ),
        _Fact(context.tr('Listed', 'የተለጠፈው'), timeAgo(l.createdAt)),
        if (l.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(l.description, style: t.textTheme.bodyMedium),
        ],
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(l.official ? 'A Studio' : l.sellerName),
            subtitle: Text(l.official
                ? context.tr('Official A Studio shop', 'የኤ ስቱዲዮ ይፋዊ ሱቅ')
                : (l.sellerHandle.isNotEmpty ? context.tr('Artist on A Studio', 'በኤ ስቱዲዮ ያለ ባለሙያ') : context.tr('Seller', 'ሻጭ'))),
            trailing: l.sellerHandle.isNotEmpty ? const Icon(Icons.chevron_right) : null,
            onTap: l.sellerHandle.isNotEmpty ? () => context.go('/${l.sellerHandle}') : null,
          ),
        ),
        const SizedBox(height: 14),
        if (owner)
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: () => context.go('/shop/${l.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.tr('Edit', 'አስተካክል')),
            ),
            if (l.status == 'active')
              OutlinedButton(
                onPressed: () => Busy.run(context, () => ListingService.setStatus(l.id, 'sold'),
                    success: context.tr('Marked as sold', 'እንደተሸጠ ተመዝግቧል')),
                child: Text(context.tr('Mark sold', 'ተሽጧል')),
              ),
            if (l.status == 'sold')
              OutlinedButton(
                onPressed: () => Busy.run(context, () => ListingService.setStatus(l.id, 'active'),
                    success: context.tr('Back on sale', 'እንደገና ለሽያጭ ቀርቧል')),
                child: Text(context.tr('Put back on sale', 'እንደገና ለሽያጭ')),
              ),
            TextButton(
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: context.tr('Delete this listing?', 'ይህ እቃ ይሰረዝ?'), confirm: context.tr('Delete', 'ሰርዝ'), danger: true);
                if (!ok || !context.mounted) return;
                await Busy.run(context, () => ListingService.delete(l));
                if (context.mounted) context.go('/shop');
              },
              child: Text(context.tr('Delete', 'ሰርዝ'), style: TextStyle(color: t.colorScheme.error)),
            ),
          ])
        else if (l.status == 'active')
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: () => _message(l),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(context.tr('Message seller', 'ለሻጩ መልዕክት')),
            ),
            if (l.whatsapp.isNotEmpty)
              OutlinedButton(
                onPressed: () => openExternal(
                    'https://wa.me/${whatsappDigits(l.whatsapp)}?text=${Uri.encodeComponent(context.tr('Selam, is this still available? ${_link(l)}', 'ሰላም፣ ይህ አሁንም አለ? ${_link(l)}'))}'),
                child: const Text('WhatsApp'),
              ),
            if (l.telegram.isNotEmpty)
              OutlinedButton(
                onPressed: () => openExternal('https://t.me/${telegramUsername(l.telegram)}'),
                child: const Text('Telegram'),
              ),
          ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, children: [
          TextButton.icon(
            onPressed: () async {
              final ok = await bridge.nativeShare(title: l.title, text: l.title, url: _link(l));
              if (!ok && context.mounted) await copyText(context, _link(l), done: context.tr('Link copied', 'ሊንኩ ተቀድቷል'));
            },
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(context.tr('Share', 'አጋራ')),
          ),
          if (!owner)
            TextButton.icon(
              onPressed: () => _report(l),
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text(context.tr('Report', 'ሪፖርት')),
            ),
          if (me.isAdmin && l.status != 'removed')
            TextButton.icon(
              onPressed: () => Busy.run(context, () => AdminService.setListingStatus(l, 'removed'),
                  success: context.tr('Listing removed', 'እቃው ተወግዷል')),
              icon: const Icon(Icons.block, size: 18),
              label: Text(context.tr('Remove (admin)', 'አስወግድ (አስተዳዳሪ)')),
            ),
        ]),
        const SizedBox(height: 10),
        Text(
          context.tr(
              'A Studio does not take payment or deliver for The Vanity. Meet somewhere public, check seals and expiry dates, then pay the seller directly.',
              'ኤ ስቱዲዮ ለሱቁ ክፍያ አይቀበልም ወይም አያደርስም። በሕዝብ ቦታ ተገናኝተው ማሸጊያውን እና የአገልግሎት ጊዜውን ያረጋግጡ፣ ከዚያ ለሻጩ በቀጥታ ይክፈሉ።'),
          style: t.textTheme.bodySmall,
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageBody(
          maxWidth: 1040,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/shop'),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(context.tr('The Vanity', 'የውበት ሱቅ')),
                ),
                const SizedBox(height: 8),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: gallery),
                    const SizedBox(width: 32),
                    Expanded(child: details),
                  ])
                else ...[
                  gallery,
                  const SizedBox(height: 20),
                  details,
                ],
              ],
            ),
          ),
        ),
        const SiteFooter(),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _Fact(this.label, this.value, {this.warn = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
          Expanded(
            child: Text(value, style: TextStyle(color: warn ? AppColors.honey : null, fontFamily: 'DMSans')),
          ),
        ]),
      );
}
