import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/chat_service.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context) => SignedInGate(builder: (_) => const _Inbox());
}

class _Inbox extends StatefulWidget {
  const _Inbox();
  @override
  State<_Inbox> createState() => _InboxState();
}

class _InboxState extends State<_Inbox> {
  late final Stream<List<Chat>> _chats = ChatService.myChats();

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.uid;
    final t = Theme.of(context);
    return StreamBuilder<List<Chat>>(
      stream: _chats,
      builder: (context, snap) {
        final chats = snap.data ?? const <Chat>[];
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageBody(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(context.tr('Messages', 'መልዕክቶች')),
                  if (snap.hasError)
                    ErrorView(context.tr('Could not load your messages.', 'መልዕክቶችዎን መጫን አልተቻለም።'))
                  else if (!snap.hasData)
                    const Loading()
                  else if (chats.isEmpty)
                    EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: context.tr('No messages yet', 'ገና መልዕክት የለም'),
                      body: context.tr('Message an artist from her studio page, or a seller from a listing.',
                          'ለባለሙያ ከስቱዲዮ ገጿ፣ ለሻጭ ከእቃው ገጽ መልዕክት ይላኩ።'),
                      action: FilledButton(
                        onPressed: () => context.go('/explore'),
                        child: Text(context.tr('Find an artist', 'ባለሙያ ያግኙ')),
                      ),
                    )
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        for (var i = 0; i < chats.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 76),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: Avatar(url: chats[i].otherPhoto(me), name: chats[i].otherName(me), size: 48),
                            title: Text(
                              chats[i].otherName(me),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: chats[i].unreadFor(me) > 0
                                  ? t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
                                  : t.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              '${chats[i].lastSenderUid == me ? context.tr('You: ', 'እርስዎ፡ ') : ''}${chats[i].lastMessage}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(timeAgo(chats[i].updatedAt), style: t.textTheme.bodySmall),
                                const SizedBox(height: 4),
                                if (chats[i].unreadFor(me) > 0) Badge(label: Text('${chats[i].unreadFor(me)}')),
                              ],
                            ),
                            onTap: () => context.go('/inbox/${chats[i].id}'),
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
