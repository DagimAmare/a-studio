import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/admin_service.dart';
import '../../theme/colors.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import 'backstage_people.dart';
import 'backstage_screen.dart';

// ===================================================================== bookings

class AdminBookingsTab extends StatefulWidget {
  const AdminBookingsTab({super.key});
  @override
  State<AdminBookingsTab> createState() => _AdminBookingsTabState();
}

class _AdminBookingsTabState extends State<AdminBookingsTab> {
  late final Stream<List<Booking>> _stream = AdminService.bookings();
  String _filter = 'open';
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: _stream,
      builder: (context, snap) {
        final q = _q.text.trim().toLowerCase();
        final all = snap.data ?? const <Booking>[];
        final list = all
            .where((b) => _filter == 'all' || (_filter == 'open' ? b.isOpen : !b.isOpen))
            .where((b) => q.isEmpty || '${b.ref} ${b.clientName} ${b.artistName} ${b.artistHandle}'.toLowerCase().contains(q))
            .toList();
        final deposits = all.where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
            .fold<int>(0, (a, b) => a + b.depositAmount);
        final noShows = all.where((b) => b.status == BookingStatus.noShow).length;
        final cancelled = all.where((b) => b.status == BookingStatus.cancelledArtist || b.status == BookingStatus.cancelledClient).length;
        return AdminPage(
          title: 'Bookings',
          intro: 'Latest 300. Deposits confirmed: ${birr(deposits)} · cancellations: $cancelled · no-shows: $noShows.',
          children: [
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Reference, client or artist'),
                ),
              ),
              for (final f in const [('open', 'Open'), ('closed', 'Closed'), ('all', 'All')])
                ChoiceChip(label: Text(f.$2), selected: _filter == f.$1, onSelected: (_) => setState(() => _filter = f.$1)),
            ]),
            const SizedBox(height: 12),
            if (!snap.hasData) const Loading(),
            for (final b in list)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.circle, size: 12, color: statusColor(b.status)),
                  title: Text('${b.ref} · ${b.clientName} with ${b.artistName}'),
                  subtitle: Text(
                    '${b.date} at ${clockLabel(b.startMin)} · ${b.servicesLabel} · ${BookingStatus.label(b.status, false)}'
                    '${b.depositAmount > 0 ? ' · deposit ${birr(b.depositAmount)}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => context.go('/bookings/${b.id}'),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===================================================================== shop

class AdminShopTab extends StatefulWidget {
  const AdminShopTab({super.key});
  @override
  State<AdminShopTab> createState() => _AdminShopTabState();
}

class _AdminShopTabState extends State<AdminShopTab> {
  late final Stream<List<Listing>> _stream = AdminService.listings();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return StreamBuilder<List<Listing>>(
      stream: _stream,
      builder: (context, snap) {
        final list = [...(snap.data ?? const <Listing>[])];
        return AdminPage(
          title: 'Shop moderation',
          intro: 'Items with words like mercury, bleach, replica or prescription are flagged for a look. Post an official A Studio item from The Vanity with "Sell an item".',
          trailing: FilledButton.icon(
            onPressed: () => context.go('/shop/new'),
            icon: const Icon(Icons.add),
            label: const Text('A Studio item'),
          ),
          children: [
            if (!snap.hasData) const Loading(),
            for (final l in list)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: NetImage(l.cover, width: 52, height: 52, radius: BorderRadius.circular(10)),
                  title: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${birr(l.price)} · ${l.sellerName} · ${l.status}${l.official ? ' · official' : ''}',
                      style: t.textTheme.bodySmall),
                  onTap: () => context.go('/shop/${l.id}'),
                  trailing: l.status == 'removed'
                      ? TextButton(
                          onPressed: () => Busy.run(context, () => AdminService.setListingStatus(l, 'active'), success: 'Restored'),
                          child: const Text('Restore'),
                        )
                      : TextButton(
                          onPressed: () async {
                            final ok = await confirmDialog(context,
                                title: 'Remove "${l.title}"?', body: 'It disappears from the shop. The seller can still see it.', confirm: 'Remove', danger: true);
                            if (ok && context.mounted) {
                              await Busy.run(context, () => AdminService.setListingStatus(l, 'removed'), success: 'Removed');
                            }
                          },
                          child: const Text('Remove', style: TextStyle(color: AppColors.rouge)),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===================================================================== reports

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  late final Stream<List<Report>> _stream = AdminService.reports();
  bool _open = true;

  Future<void> _resolve(Report r) async {
    final note = await textPrompt(context,
        title: 'Resolve this report',
        hint: 'What you decided and did. This is kept in the log.',
        required: true,
        confirm: 'Resolve');
    if (note == null || !mounted) return;
    await Busy.run(context, () => AdminService.resolveReport(r, note), success: 'Resolved');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return StreamBuilder<List<Report>>(
      stream: _stream,
      builder: (context, snap) {
        final list = (snap.data ?? const <Report>[]).where((r) => _open ? r.status == 'open' : r.status != 'open').toList();
        return AdminPage(
          title: 'Reports',
          intro: 'Aim to act within 48 hours. Photo removal requests from clients should be handled the same day.',
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Open')),
                ButtonSegment(value: false, label: Text('Resolved')),
              ],
              selected: {_open},
              onSelectionChanged: (v) => setState(() => _open = v.first),
            ),
            const SizedBox(height: 12),
            if (!snap.hasData)
              const Loading()
            else if (list.isEmpty)
              const EmptyState(icon: Icons.flag_outlined, title: 'Nothing here'),
            for (final r in list)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.targetType}: ${r.targetLabel}', style: t.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(r.reason),
                    if (r.details.isNotEmpty) Text(r.details, style: t.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('from ${r.reporterName} · ${timeAgo(r.createdAt)}', style: t.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(spacing: 10, children: [
                      if (reportTargetLink(r.targetType, r.targetId, r.targetLabel) != null)
                        OutlinedButton(
                          onPressed: () => context.go(reportTargetLink(r.targetType, r.targetId, r.targetLabel)!),
                          child: const Text('Open'),
                        ),
                      TextButton(onPressed: () => copyText(context, r.targetId), child: const Text('Copy ID')),
                      if (r.status == 'open') FilledButton(onPressed: () => _resolve(r), child: const Text('Resolve')),
                    ]),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}
