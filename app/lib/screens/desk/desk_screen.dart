import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/booking_service.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../widgets/gate.dart';
import '../../widgets/shell.dart';
import 'desk_bookings.dart';
import 'desk_decor.dart';
import 'desk_hours.dart';
import 'desk_overview.dart';
import 'desk_payments.dart';
import 'desk_portfolio.dart';
import 'desk_profile.dart';
import 'desk_reviews.dart';
import 'desk_sell.dart';
import 'desk_services.dart';

class DeskTab {
  final String id;
  final IconData icon;
  final String en;
  final String am;
  const DeskTab(this.id, this.icon, this.en, this.am);
}

const List<DeskTab> kDeskTabs = [
  DeskTab('overview', Icons.space_dashboard_outlined, 'Overview', 'አጠቃላይ'),
  DeskTab('bookings', Icons.event_note_outlined, 'Bookings', 'ቀጠሮዎች'),
  DeskTab('services', Icons.brush_outlined, 'Services', 'አገልግሎቶች'),
  DeskTab('portfolio', Icons.photo_library_outlined, 'Portfolio', 'ሥራዎቼ'),
  DeskTab('hours', Icons.schedule_outlined, 'Hours', 'የሥራ ሰዓት'),
  DeskTab('decor', Icons.palette_outlined, 'Decor your studio', 'ስቱዲዮዎን ያስውቡ'),
  DeskTab('payments', Icons.account_balance_wallet_outlined, 'Deposits & policy', 'ቅድመ ክፍያ እና ፖሊሲ'),
  DeskTab('profile', Icons.person_outline, 'Profile & contact', 'መገለጫ እና አድራሻ'),
  DeskTab('reviews', Icons.star_outline, 'Reviews', 'ግምገማዎች'),
  DeskTab('sell', Icons.shopping_bag_outlined, 'Sell', 'ሽያጭ'),
];

class DeskScreen extends StatelessWidget {
  final String initialTab;
  const DeskScreen({super.key, this.initialTab = ''});

  @override
  Widget build(BuildContext context) {
    return SignedInGate(builder: (context) {
      final s = Session.instance;
      if (!s.studioLoaded) return const Loading();
      final studio = s.studio;
      if (studio == null) {
        return EmptyState(
          icon: Icons.storefront_outlined,
          title: context.tr('Open your studio', 'ስቱዲዮዎን ይክፈቱ'),
          body: context.tr('Your own page and link, bookings with deposits, and reviews. It takes about 10 minutes.',
              'የራስዎ ገጽ እና ሊንክ፣ ቅድመ ክፍያ ያላቸው ቀጠሮዎች እና ግምገማዎች። 10 ደቂቃ ያህል ይወስዳል።'),
          action: FilledButton(
            onPressed: () => context.go('/desk/setup'),
            child: Text(context.tr('Set up my studio', 'ስቱዲዮዬን አዘጋጅ')),
          ),
        );
      }
      return _Desk(studio: studio, initialTab: initialTab);
    });
  }
}

class _Desk extends StatefulWidget {
  final Studio studio;
  final String initialTab;
  const _Desk({required this.studio, required this.initialTab});
  @override
  State<_Desk> createState() => _DeskState();
}

class _DeskState extends State<_Desk> {
  late int _index = _indexOf(widget.initialTab);
  late final Stream<List<Booking>> _bookings = BookingService.asArtist();

  static int _indexOf(String id) {
    final i = kDeskTabs.indexWhere((t) => t.id == id);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(covariant _Desk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab && widget.initialTab.isNotEmpty) {
      _index = _indexOf(widget.initialTab);
    }
  }

  void _open(String id) => setState(() => _index = _indexOf(id));

  Widget _body(Studio s, List<Booking> bookings) {
    switch (kDeskTabs[_index].id) {
      case 'bookings':
        return BookingsTab(studio: s, bookings: bookings);
      case 'services':
        return ServicesTab(studio: s);
      case 'portfolio':
        return PortfolioTab(studio: s);
      case 'hours':
        return HoursTab(studio: s);
      case 'decor':
        return DecorTab(studio: s);
      case 'payments':
        return PaymentsTab(studio: s);
      case 'profile':
        return ProfileTab(studio: s);
      case 'reviews':
        return ReviewsTab(studio: s);
      case 'sell':
        return SellTab(studio: s);
      default:
        return OverviewTab(studio: s, bookings: bookings, onOpen: _open);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWide;
    return StreamBuilder<List<Booking>>(
      stream: _bookings,
      builder: (context, snap) {
        final bookings = snap.data ?? const <Booking>[];
        final pending = bookings
            .where((b) => b.status == BookingStatus.requested || b.status == BookingStatus.depositSubmitted)
            .length;
        final body = KeyedSubtree(
          key: ValueKey(kDeskTabs[_index].id),
          child: _body(widget.studio, bookings),
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 250,
                child: _SideMenu(studio: widget.studio, index: _index, pending: pending, onTap: (i) => setState(() => _index = i)),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          );
        }
        return Column(
          children: [
            _TopTabs(index: _index, pending: pending, onTap: (i) => setState(() => _index = i)),
            const Divider(height: 1),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _SideMenu extends StatelessWidget {
  final Studio studio;
  final int index;
  final int pending;
  final ValueChanged<int> onTap;
  const _SideMenu({required this.studio, required this.index, required this.pending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Text(context.tr('STUDIO DESK', 'የስቱዲዮ ዴስክ'), style: labelCaps()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
          child: Text(studio.name, style: displayStyle(24, color: t.colorScheme.onSurface)),
        ),
        for (var i = 0; i < kDeskTabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              selected: i == index,
              selectedTileColor: AppColors.petal.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: Icon(kDeskTabs[i].icon, size: 20),
              title: Text(context.tr(kDeskTabs[i].en, kDeskTabs[i].am)),
              trailing: kDeskTabs[i].id == 'bookings' && pending > 0
                  ? Badge(label: Text('$pending'))
                  : null,
              onTap: () => onTap(i),
            ),
          ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => context.go('/${studio.handle}'),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(context.tr('View my page', 'ገጼን ይመልከቱ')),
        ),
      ],
    );
  }
}

class _TopTabs extends StatelessWidget {
  final int index;
  final int pending;
  final ValueChanged<int> onTap;
  const _TopTabs({required this.index, required this.pending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: kDeskTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tab = kDeskTabs[i];
          final label = Text(context.tr(tab.en, tab.am));
          return ChoiceChip(
            selected: i == index,
            onSelected: (_) => onTap(i),
            avatar: Icon(tab.icon, size: 18),
            label: tab.id == 'bookings' && pending > 0
                ? Badge(label: Text('$pending'), offset: const Offset(14, -6), child: label)
                : label,
          );
        },
      ),
    );
  }
}

/// Shared frame for each Studio Desk tab.
class DeskPage extends StatelessWidget {
  final String title;
  final String? intro;
  final List<Widget> children;
  final Widget? trailing;
  const DeskPage({super.key, required this.title, this.intro, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        PageBody(
          maxWidth: 860,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title, trailing: trailing),
              if (intro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(intro!,
                      style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ),
              ...children,
            ],
          ),
        ),
      ],
    );
  }
}

/// A titled card block used across the desk.
class DeskCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final Widget? trailing;
  const DeskCard({super.key, this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Expanded(child: Text(title!, style: t.textTheme.titleLarge)),
                    if (trailing != null) trailing!,
                  ]),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
