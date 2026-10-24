import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'l10n/tr.dart';
import 'screens/account_screen.dart';
import 'screens/auth_screens.dart';
import 'screens/backstage/backstage_screen.dart';
import 'screens/booking_detail_screen.dart';
import 'screens/booking_flow_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/desk/desk_screen.dart';
import 'screens/desk/desk_setup_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/listing_detail_screen.dart';
import 'screens/listing_editor_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/setup_needed_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/studio_screen.dart';
import 'services/session.dart';
import 'theme/app_theme.dart';
import 'widgets/shell.dart';

class AStudioApp extends StatefulWidget {
  final bool firebaseReady;
  const AStudioApp({super.key, required this.firebaseReady});

  @override
  State<AStudioApp> createState() => _AStudioAppState();
}

class _AStudioAppState extends State<AStudioApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController.instance,
      builder: (context, locale, _) {
        if (!widget.firebaseReady) {
          return MaterialApp(
            title: 'A Studio',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            locale: locale,
            supportedLocales: kSupportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const SetupNeededScreen(),
          );
        }
        return MaterialApp.router(
          title: 'A Studio',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: locale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: _router,
        );
      },
    );
  }
}

const _authRequired = [
  '/inbox',
  '/message',
  '/notifications',
  '/bookings',
  '/desk',
  '/account',
  '/backstage',
  '/shop/new',
  '/welcome',
];

String _withQuery(String path, Map<String, String> q) =>
    q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();

/// Only paths inside the app may be a `next` target.
String _safeNext(String? next) {
  if (next == null || next.isEmpty) return '';
  if (!next.startsWith('/') || next.startsWith('//')) return '';
  return next;
}

String? _redirect(BuildContext context, GoRouterState state) {
  final s = Session.instance;
  final path = state.uri.path;
  if (!s.authKnown || s.holdRedirects) return null;
  var needsAuth = _authRequired.any((p) => path == p || path.startsWith('$p/'));
  if (path.startsWith('/shop/') && path.endsWith('/edit')) needsAuth = true;
  if (needsAuth && !s.signedIn) {
    return _withQuery('/signin', {'next': state.uri.toString()});
  }
  if (!s.signedIn || !s.profileLoaded) return null;
  final next = _safeNext(state.uri.queryParameters['next']);
  final role = state.uri.queryParameters['role'] ?? '';
  final authPage = path == '/signin' || path == '/signup';
  if (s.profile == null) {
    if (path == '/welcome') return null;
    final target = authPage ? next : state.uri.toString();
    return _withQuery('/welcome', {
      if (target.isNotEmpty) 'next': target,
      if (role.isNotEmpty) 'role': role,
    });
  }
  if (authPage || path == '/welcome') {
    if (role == 'artist' && s.studio == null) return '/desk/setup';
    return next.isEmpty ? '/' : next;
  }
  return null;
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: Session.instance,
    redirect: _redirect,
    errorBuilder: (c, s) => AppShell(location: s.uri.path, child: const NotFoundView()),
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
          GoRoute(
            path: '/explore',
            builder: (c, s) => ExploreScreen(
              initialQuery: s.uri.queryParameters['q'] ?? '',
              initialService: s.uri.queryParameters['service'] ?? '',
              initialOccasion: s.uri.queryParameters['occasion'] ?? '',
            ),
          ),
          GoRoute(path: '/shop', builder: (c, s) => const ShopScreen()),
          GoRoute(path: '/shop/new', builder: (c, s) => const ListingEditorScreen()),
          GoRoute(
            path: '/shop/:id',
            builder: (c, s) => ListingDetailScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/shop/:id/edit',
            builder: (c, s) => ListingEditorScreen(listingId: s.pathParameters['id']),
          ),
          GoRoute(
            path: '/signin',
            builder: (c, s) => SignInScreen(
              next: s.uri.queryParameters['next'] ?? '',
              role: s.uri.queryParameters['role'] ?? '',
            ),
          ),
          GoRoute(
            path: '/signup',
            builder: (c, s) => SignUpScreen(
              next: s.uri.queryParameters['next'] ?? '',
              role: s.uri.queryParameters['role'] ?? 'client',
            ),
          ),
          GoRoute(
            path: '/welcome',
            builder: (c, s) => WelcomeScreen(
              next: s.uri.queryParameters['next'] ?? '',
              role: s.uri.queryParameters['role'] ?? '',
            ),
          ),
          GoRoute(path: '/inbox', builder: (c, s) => const InboxScreen()),
          GoRoute(
            path: '/inbox/:chatId',
            builder: (c, s) => ChatScreen(chatId: s.pathParameters['chatId']!),
          ),
          GoRoute(
            path: '/message/:uid',
            builder: (c, s) => ChatScreen(
              otherUid: s.pathParameters['uid']!,
              otherName: s.uri.queryParameters['name'] ?? '',
              otherPhoto: s.uri.queryParameters['photo'] ?? '',
              contextKind: s.uri.queryParameters['kind'] ?? '',
              contextId: s.uri.queryParameters['ref'] ?? '',
              contextTitle: s.uri.queryParameters['title'] ?? '',
              contextLink: s.uri.queryParameters['link'] ?? '',
            ),
          ),
          GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
          GoRoute(path: '/bookings', builder: (c, s) => const MyBookingsScreen()),
          GoRoute(
            path: '/bookings/:id',
            builder: (c, s) => BookingDetailScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/book/:handle',
            builder: (c, s) => BookingFlowScreen(handle: s.pathParameters['handle']!),
          ),
          GoRoute(
            path: '/desk',
            builder: (c, s) => DeskScreen(initialTab: s.uri.queryParameters['tab'] ?? ''),
          ),
          GoRoute(path: '/desk/setup', builder: (c, s) => const DeskSetupScreen()),
          GoRoute(path: '/account', builder: (c, s) => const AccountScreen()),
          GoRoute(path: '/backstage', builder: (c, s) => const BackstageScreen()),
          GoRoute(
            path: '/:handle',
            builder: (c, s) => StudioScreen(handle: s.pathParameters['handle']!.toLowerCase()),
          ),
        ],
      ),
    ],
  );
}
