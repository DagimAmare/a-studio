import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/format.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../services/session.dart';
import '../theme/colors.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => SignedInGate(builder: (_) => const _Notifications());
}

class _Notifications extends StatefulWidget {
  const _Notifications();
  @override
  State<_Notifications> createState() => _NotificationsState();
}

IconData _iconFor(String type) {
  if (type == 'message') return Icons.chat_bubble_outline;
  if (type == 'review') return Icons.star_outline;
  if (type.startsWith('booking')) return Icons.event_note_outlined;
  if (type.startsWith('listing')) return Icons.shopping_bag_outlined;
  if (type == 'announcement' || type == 'campaign') return Icons.campaign_outlined;
  if (type == 'birthday') return Icons.cake_outlined;
  return Icons.notifications_none;
}

class _NotificationsState extends State<_Notifications> {
  late final Stream<List<AppNotification>> _stream = NotificationService.mine();

  void _open(AppNotification n) {
    if (!n.read) NotificationService.markRead(n.id);
    if (n.link.isNotEmpty && n.link.startsWith('/')) context.go(n.link);
  }

  Future<void> _enablePush() async {
    final ok = await PushService.enable(Session.instance.uid);
    if (!mounted) return;
    toast(
        context,
        ok
            ? context.tr('Alerts are on for this device', 'በዚህ መሣሪያ ማሳወቂያዎች በርተዋል')
            : context.tr('Your browser blocked alerts. Allow notifications for this site in its settings.',
                'አሳሽዎ ማሳወቂያዎችን ከልክሏል። በቅንብሮቹ ውስጥ ለዚህ ጣቢያ ይፍቀዱ።'));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snap) {
        final list = snap.data ?? const <AppNotification>[];
        final unread = list.where((n) => !n.read).length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageBody(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    context.tr('Notifications', 'ማሳወቂያዎች'),
                    trailing: unread > 0
                        ? TextButton(
                            onPressed: () => NotificationService.markAllRead(list),
                            child: Text(context.tr('Mark all read', 'ሁሉንም እንደተነበበ')),
                          )
                        : null,
                  ),
                  if (AppConfig.pushConfigured)
                    ValueListenableBuilder<bool>(
                      valueListenable: PushService.enabled,
                      builder: (context, on, _) => on
                          ? const SizedBox.shrink()
                          : Card(
                              color: AppColors.petal,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ListTile(
                                leading: const Icon(Icons.notifications_active_outlined),
                                title: Text(context.tr('Get alerts on this device', 'በዚህ መሣሪያ ማሳወቂያ ያግኙ')),
                                subtitle: Text(context.tr(
                                    'Booking updates and messages, even when A Studio is closed. On iPhone, add A Studio to your home screen first.',
                                    'የቀጠሮ ዝመናዎች እና መልዕክቶች፣ ኤ ስቱዲዮ ዝግ ቢሆንም። በአይፎን መጀመሪያ ወደ መነሻ ገጽ ያክሉ።')),
                                trailing: FilledButton(onPressed: _enablePush, child: Text(context.tr('Turn on', 'አብራ'))),
                              ),
                            ),
                    ),
                  if (snap.hasError)
                    ErrorView(context.tr('Could not load notifications.', 'ማሳወቂያዎችን መጫን አልተቻለም።'))
                  else if (!snap.hasData)
                    const Loading()
                  else if (list.isEmpty)
                    EmptyState(
                      icon: Icons.notifications_none,
                      title: context.tr('You are all caught up', 'ሁሉንም አይተዋል'),
                    )
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          Dismissible(
                            key: ValueKey(list[i].id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: AppColors.rouge,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline, color: AppColors.milk),
                            ),
                            onDismissed: (_) => NotificationService.delete(list[i].id).catchError((_) {}),
                            child: ListTile(
                              tileColor: list[i].read ? null : AppColors.petal.withValues(alpha: 0.35),
                              leading: Icon(_iconFor(list[i].type)),
                              title: Text(list[i].title,
                                  style: list[i].read
                                      ? t.textTheme.titleSmall
                                      : t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                [if (list[i].body.isNotEmpty) list[i].body, timeAgo(list[i].createdAt)].join('\n'),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: list[i].body.isNotEmpty,
                              onTap: () => _open(list[i]),
                            ),
                          ),
                        ],
                      ]),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
