import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../l10n/tr.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'brand.dart';
import 'common.dart';

const double kWide = 900;

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWide;
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final s = Session.instance;
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: _TopBar(wide: wide, location: location),
          ),
          body: child,
          bottomNavigationBar: wide ? null : _BottomNav(location: location, artist: s.isArtist),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool wide;
  final String location;
  const _TopBar({required this.wide, required this.location});

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final t = Theme.of(context);
    Widget navLink(String label, String path) {
      final active = path == '/' ? location == '/' : location.startsWith(path);
      return TextButton(
        onPressed: () => context.go(path),
        style: TextButton.styleFrom(
          foregroundColor: active ? t.colorScheme.onSurface : t.colorScheme.onSurfaceVariant,
        ),
        child: Text(label),
      );
    }

    return Material(
      color: t.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.dividerColor))),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.go('/'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Wordmark(size: wide ? 22 : 18),
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 18),
                navLink(context.tr('Explore', 'ያስሱ'), '/explore'),
                navLink(context.tr('The Vanity', 'ሱቅ'), '/shop'),
                if (s.isArtist) navLink(context.tr('Studio Desk', 'የስቱዲዮ ዴስክ'), '/desk'),
                if (s.signedIn) navLink(context.tr('Bookings', 'ቀጠሮዎች'), '/bookings'),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => LocaleController.instance.toggle(),
                child: Text(context.isAm ? 'EN' : 'አማ'),
              ),
              if (s.signedIn) ...[
                IconButton(
                  tooltip: context.tr('Messages', 'መልዕክቶች'),
                  onPressed: () => context.go('/inbox'),
                  icon: Badge(
                    isLabelVisible: s.unreadChats > 0,
                    label: Text('${s.unreadChats}'),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Notifications', 'ማሳወቂያዎች'),
                  onPressed: () => context.go('/notifications'),
                  icon: Badge(
                    isLabelVisible: s.unreadNotifications > 0,
                    label: Text('${s.unreadNotifications}'),
                    child: const Icon(Icons.notifications_none),
                  ),
                ),
                if (wide) _AccountMenu(),
              ] else ...[
                if (wide)
                  TextButton(
                    onPressed: () => context.go('/signup?role=artist'),
                    child: Text(context.tr('For artists', 'ለባለሙያዎች')),
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(40, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8)),
                  onPressed: () => context.go('/signin?next=${Uri.encodeComponent(location)}'),
                  child: Text(context.tr('Sign in', 'ይግቡ')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return PopupMenuButton<String>(
      tooltip: context.tr('Account', 'መለያ'),
      offset: const Offset(0, 48),
      onSelected: (v) async {
        if (v == 'signout') {
          await s.signOut();
          if (context.mounted) context.go('/');
        } else {
          context.go(v);
        }
      },
      itemBuilder: (c) => [
        PopupMenuItem(value: '/account', child: Text(c.tr('Account', 'መለያ'))),
        PopupMenuItem(value: '/bookings', child: Text(c.tr('My bookings', 'ቀጠሮዎቼ'))),
        if (s.isArtist) PopupMenuItem(value: '/desk', child: Text(c.tr('Studio Desk', 'የስቱዲዮ ዴስክ'))),
        if (!s.isArtist) PopupMenuItem(value: '/desk/setup', child: Text(c.tr('Become an artist', 'ባለሙያ ይሁኑ'))),
        if (s.isAdmin) PopupMenuItem(value: '/backstage', child: Text(c.tr('Backstage', 'የአስተዳደር ገጽ'))),
        PopupMenuItem(value: 'signout', child: Text(c.tr('Sign out', 'ይውጡ'))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Avatar(
          url: s.profile?.photoUrl ?? s.studio?.avatarUrl ?? '',
          name: s.displayName,
          size: 34,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final String location;
  final bool artist;
  const _BottomNav({required this.location, required this.artist});

  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, String)>[
      ('/', Icons.home_outlined, context.tr('Home', 'መነሻ')),
      ('/explore', Icons.search, context.tr('Explore', 'ያስሱ')),
      ('/shop', Icons.shopping_bag_outlined, context.tr('Shop', 'ሱቅ')),
      if (artist)
        ('/desk', Icons.dashboard_outlined, context.tr('Desk', 'ዴስክ'))
      else
        ('/bookings', Icons.event_outlined, context.tr('Bookings', 'ቀጠሮ')),
      ('/account', Icons.person_outline, context.tr('Me', 'እኔ')),
    ];
    var index = 0;
    for (var i = 0; i < items.length; i++) {
      final p = items[i].$1;
      if (p == '/' ? location == '/' : location.startsWith(p)) index = i;
    }
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) => context.go(items[i].$1),
      destinations: [
        for (final it in items) NavigationDestination(icon: Icon(it.$2), label: it.$3),
      ],
    );
  }
}

/// Site footer with the legal links and the intermediary disclaimer.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = t.textTheme.bodySmall;
    return Container(
      margin: const EdgeInsets.only(top: 48),
      color: AppColors.espresso,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      child: PageBody(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Wordmark(size: 24, color: AppColors.milk),
            const SizedBox(height: 18),
            const TibebBorder(height: 20),
            const SizedBox(height: 18),
            Text(
              context.tr(
                  'A Studio is a marketplace that connects clients with independent beauty artists. Services and items are provided by the artists and sellers themselves, not by A Studio.',
                  'ኤ ስቱዲዮ ደንበኞችን ከገለልተኛ የውበት ባለሙያዎች ጋር የሚያገናኝ የገበያ መድረክ ነው። አገልግሎቶቹ እና እቃዎቹ የሚቀርቡት በባለሙያዎቹ እና በሻጮቹ ራሳቸው እንጂ በኤ ስቱዲዮ አይደለም።'),
              style: muted?.copyWith(color: AppColors.noirMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _FooterLink(context.tr('Terms', 'የአገልግሎት ውል'), AppConfig.termsPath),
                _FooterLink(context.tr('Privacy', 'ግላዊነት'), AppConfig.privacyPath),
                _FooterLink(context.tr('Delete your data', 'ውሂብዎን ይሰርዙ'), AppConfig.deletionPath),
                _FooterLink(AppConfig.supportEmail, 'mailto:${AppConfig.supportEmail}'),
              ],
            ),
            const SizedBox(height: 18),
            Text('© ${DateTime.now().year} A Studio · Addis Ababa',
                style: labelCaps(color: AppColors.noirMuted, size: 11, spacing: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final String href;
  const _FooterLink(this.label, this.href);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => href.startsWith('mailto:') ? openExternal(href) : openSameTab(href),
        child: Text(label,
            style: const TextStyle(
                fontFamily: 'DMSans',
                color: AppColors.milk,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.noirMuted,
                fontSize: 14)),
      );
}
