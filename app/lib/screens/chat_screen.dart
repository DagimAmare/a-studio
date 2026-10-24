import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/media_service.dart';
import '../services/report_service.dart';
import '../services/session.dart';
import '../theme/colors.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';
import '../widgets/media_viewer.dart';

/// One conversation. Opened either by chat id (from the inbox) or by the
/// other person's uid (from a studio, booking or listing), optionally with
/// a booking or listing card to attach to the first message.
class ChatScreen extends StatelessWidget {
  final String? chatId;
  final String? otherUid;
  final String otherName;
  final String otherPhoto;
  final String contextKind;
  final String contextId;
  final String contextTitle;
  final String contextLink;
  const ChatScreen({
    super.key,
    this.chatId,
    this.otherUid,
    this.otherName = '',
    this.otherPhoto = '',
    this.contextKind = '',
    this.contextId = '',
    this.contextTitle = '',
    this.contextLink = '',
  });

  @override
  Widget build(BuildContext context) => SignedInGate(builder: (_) => _Chat(screen: this));
}

class _Chat extends StatefulWidget {
  final ChatScreen screen;
  const _Chat({required this.screen});
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final String _me = Session.instance.uid;
  late final String _chatId = widget.screen.chatId ?? ChatService.chatIdWith(widget.screen.otherUid ?? '');
  late final Stream<Chat?> _chat = ChatService.watch(_chatId);
  late final Stream<List<ChatMessage>> _messages = ChatService.messages(_chatId);
  final _text = TextEditingController();
  late bool _attachContext =
      (widget.screen.contextKind == 'booking' || widget.screen.contextKind == 'listing') &&
          widget.screen.contextId.isNotEmpty;
  bool _sending = false;
  bool _seenScheduled = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// The other person's uid: from the route, the chat, or the chat id.
  String _otherUid(Chat? chat) {
    final fromRoute = widget.screen.otherUid;
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    if (chat != null) return chat.otherUid(_me);
    final parts = _chatId.split('_');
    return parts.firstWhere((p) => p != _me, orElse: () => '');
  }

  String _otherName(Chat? chat) {
    final fromChat = chat?.names[_otherUid(chat)] ?? '';
    if (fromChat.isNotEmpty) return fromChat;
    return widget.screen.otherName.isNotEmpty ? widget.screen.otherName : context.tr('A Studio member', 'የኤ ስቱዲዮ አባል');
  }

  String _otherPhoto(Chat? chat) {
    final fromChat = chat?.photos[_otherUid(chat)] ?? '';
    return fromChat.isNotEmpty ? fromChat : widget.screen.otherPhoto;
  }

  void _markSeenSoon(Chat? chat) {
    if (chat == null || chat.unreadFor(_me) == 0 || _seenScheduled) return;
    _seenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatService.markSeen(_chatId);
      _seenScheduled = false;
    });
  }

  Future<void> _send(Chat? chat) async {
    final text = _text.text.trim();
    if (text.isEmpty && !_attachContext) return;
    final other = _otherUid(chat);
    if (other.isEmpty || other == _me) return;
    final name = _otherName(chat);
    final photo = _otherPhoto(chat);
    setState(() => _sending = true);
    try {
      if (_attachContext) {
        await ChatService.send(
          otherUid: other,
          otherName: name,
          otherPhoto: photo,
          kind: widget.screen.contextKind,
          refId: widget.screen.contextId,
          refTitle: widget.screen.contextTitle,
          refLink: widget.screen.contextLink,
        );
        if (mounted) setState(() => _attachContext = false);
      }
      if (text.isNotEmpty) {
        await ChatService.send(otherUid: other, otherName: name, otherPhoto: photo, text: text);
        _text.clear();
      }
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto(Chat? chat) async {
    final other = _otherUid(chat);
    if (other.isEmpty || other == _me) return;
    try {
      final picked = await MediaService.pickImages(multiple: false);
      if (picked.isEmpty || !mounted) return;
      setState(() => _sending = true);
      final up = await MediaService.upload(picked.first);
      await ChatService.send(
        otherUid: other,
        otherName: _otherName(chat),
        otherPhoto: _otherPhoto(chat),
        kind: 'image',
        imageUrl: up.url,
      );
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(Chat? chat) async {
    final reason = await textPrompt(context,
        title: context.tr('Report this person', 'ይህን ሰው ሪፖርት ያድርጉ'),
        hint: context.tr('What happened? (scam, harassment, fake payment...)', 'ምን ተፈጠረ?'),
        required: true,
        confirm: context.tr('Send report', 'ሪፖርት ላክ'));
    if (reason == null || !mounted) return;
    await Busy.run(
      context,
      () => ReportService.report(
        targetType: 'user',
        targetId: _otherUid(chat),
        targetLabel: '${_otherName(chat)} (chat $_chatId)',
        reason: reason,
      ),
      success: context.tr('Thank you. Our team will look at it.', 'እናመሰግናለን። ቡድናችን ይመለከተዋል።'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final self = _otherUid(null) == _me;
    return StreamBuilder<Chat?>(
      stream: _chat,
      builder: (context, chatSnap) {
        final chat = chatSnap.data;
        if (chatSnap.hasError && widget.screen.chatId != null) {
          return ErrorView(context.tr('You cannot open this conversation.', 'ይህን ውይይት መክፈት አይችሉም።'));
        }
        _markSeenSoon(chat);
        return Column(
          children: [
            _Header(
              name: _otherName(chat),
              photo: _otherPhoto(chat),
              onBack: () => context.go('/inbox'),
              onReport: () => _report(chat),
            ),
            const Divider(height: 1),
            Expanded(
              child: self
                  ? EmptyState(icon: Icons.person_outline, title: context.tr('This is you', 'ይህ እርስዎ ነዎት'))
                  : StreamBuilder<List<ChatMessage>>(
                      stream: _messages,
                      builder: (context, snap) {
                        final msgs = snap.data ?? const <ChatMessage>[];
                        if (msgs.isEmpty) {
                          return ListView(padding: const EdgeInsets.all(20), children: [
                            const SizedBox(height: 30),
                            EmptyState(
                              icon: Icons.waving_hand_outlined,
                              title: context.tr('Say selam', 'ሰላም ይበሉ'),
                              body: context.tr(
                                  'Keep deposits inside your booking so both of you are covered. A Studio will never ask for your password or PIN.',
                                  'ሁለታችሁም እንድትጠበቁ ቅድመ ክፍያን በቀጠሮው ውስጥ ያድርጉ። ኤ ስቱዲዮ የይለፍ ቃልዎን ወይም ፒንዎን በጭራሽ አይጠይቅም።'),
                            ),
                          ]);
                        }
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: msgs.length,
                          itemBuilder: (context, i) {
                            final m = msgs[i];
                            final mine = m.senderUid == _me;
                            final images = msgs.where((x) => x.kind == 'image' && x.imageUrl.isNotEmpty).toList();
                            return _Bubble(
                              message: m,
                              mine: mine,
                              onOpenImage: () {
                                final ordered = images.reversed.toList();
                                final at = ordered.indexWhere((x) => x.id == m.id);
                                openMediaViewer(
                                  context,
                                  [for (final x in ordered) MediaItem(x.imageUrl)],
                                  at < 0 ? 0 : at,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
            if (_attachContext)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                decoration: BoxDecoration(color: AppColors.petal, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(widget.screen.contextKind == 'booking' ? Icons.event_note_outlined : Icons.shopping_bag_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.screen.contextKind == 'booking' ? context.tr('About booking', 'ስለ ቀጠሮ') : context.tr('About', 'ስለ')} ${widget.screen.contextTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Remove', 'አስወግድ'),
                    onPressed: () => setState(() => _attachContext = false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ]),
              ),
            if (!self)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: Row(children: [
                    IconButton(
                      tooltip: context.tr('Send a photo', 'ፎቶ ላክ'),
                      onPressed: _sending ? null : () => _sendPhoto(chat),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(chat),
                        decoration: InputDecoration(
                          hintText: context.tr('Write a message', 'መልዕክት ይጻፉ'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: context.tr('Send', 'ላክ'),
                      onPressed: _sending ? null : () => _send(chat),
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    ),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String photo;
  final VoidCallback onBack;
  final VoidCallback onReport;
  const _Header({required this.name, required this.photo, required this.onBack, required this.onReport});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        Avatar(url: photo, name: name, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'report') onReport();
          },
          itemBuilder: (c) => [PopupMenuItem(value: 'report', child: Text(c.tr('Report', 'ሪፖርት አድርግ')))],
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final VoidCallback onOpenImage;
  const _Bubble({required this.message, required this.mine, required this.onOpenImage});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final m = message;
    final maxW = MediaQuery.sizeOf(context).width * 0.75;
    final bg = mine ? AppColors.espresso : AppColors.oat;
    final fg = mine ? AppColors.milk : AppColors.espresso;
    Widget body;
    switch (m.kind) {
      case 'image':
        body = GestureDetector(
          onTap: onOpenImage,
          child: NetImage(m.imageUrl, width: 220, height: 220, radius: BorderRadius.circular(16)),
        );
        break;
      case 'booking':
      case 'listing':
        body = InkWell(
          onTap: m.refLink.isEmpty ? null : () => context.go(m.refLink),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.petal,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(m.kind == 'booking' ? Icons.event_note_outlined : Icons.shopping_bag_outlined, color: AppColors.cocoa),
              const SizedBox(width: 10),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(m.kind == 'booking' ? context.tr('Booking', 'ቀጠሮ') : context.tr('Listing', 'እቃ'),
                      style: t.textTheme.labelSmall),
                  Text(m.refTitle, style: t.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (m.refLink.isNotEmpty)
                    Text(context.tr('Tap to open', 'ለመክፈት ይንኩ'), style: t.textTheme.bodySmall),
                ]),
              ),
            ]),
          ),
        );
        break;
      default:
        body = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: SelectableText(m.text, style: TextStyle(color: fg, fontFamily: 'DMSans', fontSize: 15, height: 1.35)),
        );
    }
    final time = m.createdAt == null ? '' : TimeOfDay.fromDateTime(m.createdAt!).format(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW > 520 ? 520 : maxW),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              body,
              if (time.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(time, style: t.textTheme.bodySmall?.copyWith(fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
