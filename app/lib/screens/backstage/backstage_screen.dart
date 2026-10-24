import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ethiopian.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/admin_service.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../widgets/gate.dart';
import '../../widgets/shell.dart';
import 'backstage_broadcast.dart';
import 'backstage_ops.dart';
import 'backstage_people.dart';

class _BTab {
  final String id;
  final IconData icon;
  final String label;
  const _BTab(this.id, this.icon, this.label);
}

const List<_BTab> _tabs = [
  _BTab('dashboard', Icons.insights_outlined, 'Dashboard'),
  _BTab('activity', Icons.receipt_long_outlined, 'Activity log'),
  _BTab('verify', Icons.verified_user_outlined, 'Verification'),
  _BTab('artists', Icons.storefront_outlined, 'Artists'),
  _BTab('people', Icons.people_outline, 'People'),
  _BTab('bookings', Icons.event_note_outlined, 'Bookings'),
  _BTab('shop', Icons.shopping_bag_outlined, 'Shop'),
  _BTab('reports', Icons.flag_outlined, 'Reports'),
  _BTab('broadcast', Icons.campaign_outlined, 'Broadcast'),
  _BTab('calendar', Icons.calendar_month_outlined, 'Glam Calendar'),
];

/// Backstage: the admin console. Every action is also enforced by the
/// Firestore rules (admins/{uid}), and every action is logged.
class BackstageScreen extends StatelessWidget {
  const BackstageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SignedInGate(builder: (context) {
      final s = Session.instance;
      if (!s.isAdmin) return const _NotAdmin();
      return const _Backstage();
    });
  }
}

class _NotAdmin extends StatelessWidget {
  const _NotAdmin();
  @override
  Widget build(BuildContext context) {
    final uid = Session.instance.uid;
    return ListView(children: [
      PageBody(
        maxWidth: 620,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('Backstage', kicker: 'A Studio team'),
          const Text('Backstage is for the A Studio team. If you run A Studio and this is your first time here, '
              'make this account an admin once in the Firebase console:'),
          const SizedBox(height: 12),
          const Text('Firestore Database > Start collection > Collection ID: admins > Document ID: your user ID below > '
              'add a field role (string) = owner > Save. Then reload this page.'),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Your user ID'),
              subtitle: SelectableText(uid),
              trailing: IconButton(
                tooltip: 'Copy',
                onPressed: () => copyText(context, uid),
                icon: const Icon(Icons.copy),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Backstage extends StatefulWidget {
  const _Backstage();
  @override
  State<_Backstage> createState() => _BackstageState();
}

class _BackstageState extends State<_Backstage> {
  int _index = 0;
  BroadcastDraft? _draft;
  int _draftVersion = 0;

  void _open(String id, {BroadcastDraft? draft}) {
    setState(() {
      final i = _tabs.indexWhere((t) => t.id == id);
      _index = i < 0 ? 0 : i;
      if (draft != null) {
        _draft = draft;
        _draftVersion++;
      }
    });
  }

  Widget _body() {
    switch (_tabs[_index].id) {
      case 'activity':
        return const ActivityTab();
      case 'verify':
        return const VerificationTab();
      case 'artists':
        return const ArtistsTab();
      case 'people':
        return const PeopleTab();
      case 'bookings':
        return const AdminBookingsTab();
      case 'shop':
        return const AdminShopTab();
      case 'reports':
        return const ReportsTab();
      case 'broadcast':
        return BroadcastTab(key: ValueKey(_draftVersion), initial: _draft);
      case 'calendar':
        return CalendarTab(onUse: (d) => _open('broadcast', draft: d));
      default:
        return DashboardTab(onOpen: (id) => _open(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWide;
    final body = KeyedSubtree(key: ValueKey(_tabs[_index].id), child: _body());
    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 230,
          child: ListView(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Text('BACKSTAGE', style: labelCaps()),
            ),
            for (var i = 0; i < _tabs.length; i++)
              ListTile(
                dense: true,
                selected: i == _index,
                selectedTileColor: AppColors.petal.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(_tabs[i].icon, size: 20),
                title: Text(_tabs[i].label),
                onTap: () => setState(() => _index = i),
              ),
          ]),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ]);
    }
    return Column(children: [
      SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: _tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (c, i) => ChoiceChip(
            selected: i == _index,
            onSelected: (_) => setState(() => _index = i),
            avatar: Icon(_tabs[i].icon, size: 18),
            label: Text(_tabs[i].label),
          ),
        ),
      ),
      const Divider(height: 1),
      Expanded(child: body),
    ]);
  }
}

/// Shared page frame for Backstage tabs.
class AdminPage extends StatelessWidget {
  final String title;
  final String? intro;
  final Widget? trailing;
  final List<Widget> children;
  final double maxWidth;
  const AdminPage({super.key, required this.title, this.intro, this.trailing, required this.children, this.maxWidth = 1000});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        PageBody(
          maxWidth: maxWidth,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(title, trailing: trailing),
            if (intro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(intro!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ),
            ...children,
          ]),
        ),
      ],
    );
  }
}

// ===================================================================== dashboard

class DashboardTab extends StatefulWidget {
  final ValueChanged<String> onOpen;
  const DashboardTab({super.key, required this.onOpen});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late Future<AdminCounts> _counts = AdminService.counts();
  late final Stream<List<ActivityEntry>> _recent = AdminService.activity(limit: 12);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final upcoming = upcomingGlamEvents(addisNow(), days: 75);
    return AdminPage(
      title: 'Dashboard',
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: () => setState(() => _counts = AdminService.counts()),
        icon: const Icon(Icons.refresh),
      ),
      children: [
        FutureBuilder<AdminCounts>(
          future: _counts,
          builder: (context, snap) {
            final c = snap.data ?? const AdminCounts();
            Widget tile(String label, int value, {String? open, bool alert = false}) => InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: open == null ? null : () => widget.onOpen(open),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: alert && value > 0 ? AppColors.petal : AppColors.oat,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(snap.hasData ? '$value' : '·', style: displayStyle(34, color: AppColors.espresso)),
                      const SizedBox(height: 4),
                      Text(label),
                    ]),
                  ),
                );
            return Wrap(spacing: 12, runSpacing: 12, children: [
              tile('People signed up', c.users, open: 'people'),
              tile('Artists', c.artists, open: 'artists'),
              tile('Live studio pages', c.liveStudios, open: 'artists'),
              tile('Waiting for verification', c.pendingVerification, open: 'verify', alert: true),
              tile('Bookings, all time', c.bookings, open: 'bookings'),
              tile('Open bookings', c.openBookings, open: 'bookings'),
              tile('Items for sale', c.listings, open: 'shop'),
              tile('Open reports', c.openReports, open: 'reports', alert: true),
            ]);
          },
        ),
        const SizedBox(height: 24),
        Text('COMING UP ON THE GLAM CALENDAR', style: labelCaps()),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            for (final e in upcoming.take(6))
              ListTile(
                leading: Icon(e.kind == 'season'
                    ? Icons.favorite_border
                    : (e.kind == 'fast' ? Icons.spa_outlined : Icons.celebration_outlined)),
                title: Text('${e.nameEn} · ${e.nameAm}'),
                subtitle: Text(
                    '${dayLabelYear(e.start)} (${ethDayMonth(e.start)})${e.isSpan ? ' to ${dayLabel(e.end)}' : ''}${e.expected ? ' · estimate' : ''}'),
                trailing: Text(_inDays(e.start), style: t.textTheme.labelMedium),
              ),
            TextButton(onPressed: () => widget.onOpen('calendar'), child: const Text('Open the Glam Calendar')),
          ]),
        ),
        const SizedBox(height: 24),
        Text('LATEST ACTIVITY', style: labelCaps()),
        const SizedBox(height: 8),
        StreamBuilder<List<ActivityEntry>>(
          stream: _recent,
          builder: (context, snap) => Card(
            child: Column(children: [
              for (final a in snap.data ?? const <ActivityEntry>[]) ActivityRow(entry: a),
              TextButton(onPressed: () => widget.onOpen('activity'), child: const Text('See the full log')),
            ]),
          ),
        ),
      ],
    );
  }

  static String _inDays(DateTime d) {
    final now = addisNow();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (days <= 0) return 'now';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}

// ===================================================================== activity

class ActivityRow extends StatelessWidget {
  final ActivityEntry entry;
  const ActivityRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final a = entry;
    String? link;
    if (a.targetType == 'booking') link = '/bookings/${a.targetId}';
    if (a.targetType == 'listing') link = '/shop/${a.targetId}';
    return ListTile(
      dense: true,
      leading: Icon(_icon(a.type), size: 20),
      title: Text('${a.actorName} · ${a.type.replaceAll('_', ' ')}'),
      subtitle: Text([if (a.summary.isNotEmpty) a.summary, timeAgo(a.createdAt)].join(' · '),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: link == null ? null : () => context.go(link!),
    );
  }

  static IconData _icon(String type) {
    if (type.startsWith('booking')) return Icons.event_note_outlined;
    if (type.startsWith('admin')) return Icons.admin_panel_settings_outlined;
    if (type.startsWith('listing')) return Icons.shopping_bag_outlined;
    if (type.startsWith('review')) return Icons.star_outline;
    if (type.startsWith('message')) return Icons.chat_bubble_outline;
    if (type.startsWith('sign') || type.startsWith('account')) return Icons.person_outline;
    if (type.startsWith('studio') || type.startsWith('look') || type.startsWith('services')) {
      return Icons.storefront_outlined;
    }
    return Icons.bolt_outlined;
  }
}

class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});
  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  late final Stream<List<ActivityEntry>> _stream = AdminService.activity(limit: 500);
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityEntry>>(
      stream: _stream,
      builder: (context, snap) {
        final q = _q.text.trim().toLowerCase();
        final list = (snap.data ?? const <ActivityEntry>[])
            .where((a) => q.isEmpty || '${a.actorName} ${a.type} ${a.summary} ${a.targetId}'.toLowerCase().contains(q))
            .toList();
        return AdminPage(
          title: 'Activity log',
          intro: 'Every sign-up, booking step, upload, message sent (never its text), listing and admin action, newest first.',
          children: [
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filter by person, action or ID'),
            ),
            const SizedBox(height: 12),
            if (!snap.hasData)
              const Loading()
            else
              Card(child: Column(children: [for (final a in list) ActivityRow(entry: a)])),
          ],
        );
      },
    );
  }
}
