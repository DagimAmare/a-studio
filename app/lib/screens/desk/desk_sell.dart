import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/listing_service.dart';
import '../../widgets/common.dart';
import 'desk_screen.dart';

/// The artist's own listings on The Vanity.
class SellTab extends StatefulWidget {
  final Studio studio;
  const SellTab({super.key, required this.studio});
  @override
  State<SellTab> createState() => _SellTabState();
}

class _SellTabState extends State<SellTab> {
  late final Stream<List<Listing>> _mine = ListingService.bySeller(widget.studio.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Listing>>(
      stream: _mine,
      builder: (context, snap) {
        final list = (snap.data ?? const <Listing>[]).where((l) => l.status != 'removed').toList();
        return DeskPage(
          title: context.tr('Sell on The Vanity', 'በሱቁ ይሽጡ'),
          intro: context.tr('Clear your gear and sell sealed products. Your items also show on your studio page.',
              'መሣሪያዎችዎን እና ያልተከፈቱ ምርቶችን ይሽጡ። እቃዎችዎ በስቱዲዮ ገጽዎም ላይ ይታያሉ።'),
          trailing: FilledButton.icon(
            onPressed: () => context.go('/shop/new'),
            icon: const Icon(Icons.add),
            label: Text(context.tr('New listing', 'አዲስ እቃ')),
          ),
          children: [
            if (list.isEmpty && snap.connectionState != ConnectionState.waiting)
              EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: context.tr('Nothing for sale yet', 'ገና የሚሸጥ የለም'),
                body: context.tr('Ring lights, chairs, kits and sealed products sell well.', 'ሪንግ ላይት፣ ወንበሮች እና ያልተከፈቱ ምርቶች በደንብ ይሸጣሉ።'),
              ),
            for (final l in list)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  leading: NetImage(l.cover, width: 56, height: 56, radius: BorderRadius.circular(12)),
                  title: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${birr(l.price)} · ${l.status == 'sold' ? context.tr('Sold', 'ተሽጧል') : context.tr('For sale', 'ለሽያጭ')}'),
                  onTap: () => context.go('/shop/${l.id}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        context.go('/shop/${l.id}/edit');
                      } else if (v == 'sold') {
                        await Busy.run(context, () => ListingService.setStatus(l.id, 'sold'),
                            success: context.tr('Marked as sold', 'እንደተሸጠ ተመዝግቧል'));
                      } else if (v == 'active') {
                        await Busy.run(context, () => ListingService.setStatus(l.id, 'active'),
                            success: context.tr('Back on sale', 'እንደገና ለሽያጭ ቀርቧል'));
                      } else if (v == 'delete') {
                        final ok = await confirmDialog(context,
                            title: context.tr('Delete this listing?', 'ይህ እቃ ይሰረዝ?'),
                            confirm: context.tr('Delete', 'ሰርዝ'),
                            danger: true);
                        if (ok && context.mounted) {
                          await Busy.run(context, () => ListingService.delete(l), success: context.tr('Deleted', 'ተሰርዟል'));
                        }
                      }
                    },
                    itemBuilder: (c) => [
                      PopupMenuItem(value: 'edit', child: Text(c.tr('Edit', 'አስተካክል'))),
                      if (l.status == 'active') PopupMenuItem(value: 'sold', child: Text(c.tr('Mark sold', 'ተሽጧል'))),
                      if (l.status == 'sold') PopupMenuItem(value: 'active', child: Text(c.tr('Put back on sale', 'እንደገና ለሽያጭ'))),
                      PopupMenuItem(value: 'delete', child: Text(c.tr('Delete', 'ሰርዝ'))),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
