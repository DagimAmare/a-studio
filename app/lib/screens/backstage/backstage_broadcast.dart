import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/ethiopian.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import 'backstage_screen.dart';

class BroadcastDraft {
  final String title;
  final String body;
  final String titleAm;
  final String bodyAm;
  final String link;
  const BroadcastDraft({this.title = '', this.body = '', this.titleAm = '', this.bodyAm = '', this.link = '/'});
}

/// Ready-made wording for Glam Calendar events, in both languages.
BroadcastDraft draftForEvent(GlamEvent e) {
  final when = '${dayLabel(e.start)} (${ethDayMonth(e.start)})';
  switch (e.kind) {
    case 'season':
      return BroadcastDraft(
        title: '${e.nameEn} is here, {first_name}',
        body: 'Brides and guests are booking fast. Find an artist who is free on your date.',
        titleAm: '${e.nameAm} ደርሷል',
        bodyAm: 'ሙሽሮች እና እንግዶች በፍጥነት እየያዙ ነው። በቀንዎ ነጻ የሆነ ባለሙያ ያግኙ።',
        link: '/explore?occasion=bridal',
      );
    case 'fast':
      return BroadcastDraft(
        title: 'Fresh nails and hair for ${e.nameEn}',
        body: 'A quieter season for weddings is the best time for nails, braids and skin care.',
        titleAm: 'ለ${e.nameAm} ጥፍር እና ፀጉር',
        bodyAm: 'ለሠርግ ጸጥ ያለው ወቅት ለጥፍር፣ ለሹሩባ እና ለቆዳ እንክብካቤ ምርጥ ጊዜ ነው።',
        link: '/explore?service=nails',
      );
    default:
      return BroadcastDraft(
        title: '${e.nameEn} glam, {first_name}?',
        body: '${e.nameEn} is on $when. Book your look early; the best slots go first.',
        titleAm: 'የ${e.nameAm} ውበት',
        bodyAm: '${e.nameAm} ${ethDayMonth(e.start, amharic: true)} ነው። ቀድመው ይያዙ፤ ምርጥ ሰዓቶች ቀድመው ያልቃሉ።',
        link: '/explore?occasion=holiday',
      );
  }
}

class BroadcastTab extends StatefulWidget {
  final BroadcastDraft? initial;
  const BroadcastTab({super.key, this.initial});
  @override
  State<BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<BroadcastTab> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _body = TextEditingController(text: widget.initial?.body ?? '');
  late final _titleAm = TextEditingController(text: widget.initial?.titleAm ?? '');
  late final _bodyAm = TextEditingController(text: widget.initial?.bodyAm ?? '');
  late final _link = TextEditingController(text: widget.initial?.link ?? '/');
  late final Stream<List<MessageTemplate>> _templates = AdminService.templates();
  String _audience = 'everyone';
  bool _email = true;
  bool _sms = false;
  bool _marketing = true;
  int? _reach;
  String _templateId = '';
  final List<CampaignImage> _images = [];
  bool _uploading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _countReach();
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _titleAm, _bodyAm, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _countReach() async {
    setState(() => _reach = null);
    final n = await AdminService.audienceCount(_audience);
    if (mounted) setState(() => _reach = n);
  }

  void _load(MessageTemplate t) => setState(() {
        _templateId = t.id;
        _title.text = t.titleEn;
        _body.text = t.bodyEn;
        _titleAm.text = t.titleAm;
        _bodyAm.text = t.bodyAm;
        _link.text = t.link.isEmpty ? '/' : t.link;
        _images
          ..clear()
          ..addAll(t.images);
      });

  Future<void> _addImages() async {
    final room = CampaignImage.max - _images.length;
    if (room <= 0) return;
    List<PickedMedia> picked;
    try {
      picked = await MediaService.pickImages();
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
      return;
    }
    if (picked.isEmpty || !mounted) return;
    if (picked.length > room) toast(context, 'Added the first $room. A message can carry ${CampaignImage.max} pictures.');
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      for (final m in picked.take(room)) {
        if (m.mime == 'image/gif' && m.size > 2 * 1024 * 1024) {
          toast(context, '"${m.name}" is ${(m.size / 1048576).toStringAsFixed(1)} MB. GIFs under 2 MB load faster on phones.');
        }
        final img = await AdminService.uploadCampaignImage(m, onProgress: (f) {
          if (mounted) setState(() => _progress = f);
        });
        if (!mounted) return;
        setState(() {
          _images.add(img);
          _progress = 0;
        });
      }
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveTemplate() async {
    final name = await textPrompt(context, title: 'Template name', hint: 'Genna reminder', maxLines: 1, required: true);
    if (name == null || !mounted) return;
    await Busy.run(
      context,
      () => AdminService.saveTemplate(MessageTemplate(
        id: _templateId,
        name: name,
        titleEn: _title.text.trim(),
        bodyEn: _body.text.trim(),
        titleAm: _titleAm.text.trim(),
        bodyAm: _bodyAm.text.trim(),
        link: _link.text.trim(),
        images: List.of(_images),
      )),
      success: 'Template saved',
    );
  }

  String? _problem() {
    if (_uploading) return 'Wait for the pictures to finish uploading.';
    if (_title.text.trim().length < 3) return 'Write a title.';
    if (_body.text.trim().length < 5) return 'Write the message.';
    final link = _link.text.trim();
    if (link.isNotEmpty && !link.startsWith('/')) return 'Links must be pages on A Studio, starting with /';
    return null;
  }

  Future<void> _test() async {
    final p = _problem();
    if (p != null) {
      toast(context, p);
      return;
    }
    await Busy.run(
      context,
      () => AdminService.sendTest(
          title: _title.text.trim(),
          body: _body.text.trim(),
          link: _link.text.trim(),
          email: _email,
          images: List.of(_images)),
      success: 'Test sent to you. Check your notifications and email.',
    );
  }

  Future<void> _send() async {
    final p = _problem();
    if (p != null) {
      toast(context, p);
      return;
    }
    final reach = _reach ?? 0;
    final confirm = TextEditingController();
    final big = reach > 500;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Send this broadcast?'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Up to $reach people (${_marketing ? 'only those who opted in to offers' : 'everyone, as a service message'}). '
                  'In-app and push${_email ? ', plus email' : ''}${_sms ? ', plus SMS (paid)' : ''}'
                  '${_images.isEmpty ? '' : ', with ${_images.length} ${_images.length == 1 ? 'picture' : 'pictures'}'}.'),
              const SizedBox(height: 8),
              if (_email)
                const Text('Emails go out gradually (a few hundred an hour) to stay inside the mail server limits.'),
              if (big) ...[
                const SizedBox(height: 12),
                Text('Type $reach to confirm.'),
                TextField(controller: confirm, keyboardType: TextInputType.number, onChanged: (_) => set(() {})),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: !big || confirm.text.trim() == '$reach' ? () => Navigator.pop(c, true) : null,
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final sent = await Busy.run(
      context,
      () => AdminService.broadcast(
        audience: _audience,
        title: _title.text.trim(),
        body: _body.text.trim(),
        titleAm: _titleAm.text.trim(),
        bodyAm: _bodyAm.text.trim(),
        link: _link.text.trim(),
        email: _email,
        sms: _sms,
        marketingOnly: _marketing,
        images: List.of(_images),
      ),
    );
    if (sent != null && mounted) toast(context, 'Sent to $sent people');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final quiet = () {
      final h = addisNow().hour;
      return h >= 21 || h < 7;
    }();
    return AdminPage(
      title: 'Broadcast',
      intro: 'Reaches people in the app and by push, with optional email. Use {first_name} to greet each person by name. '
          'People who chose Amharic get the Amharic text when you write one.',
      maxWidth: 900,
      children: [
        StreamBuilder<List<MessageTemplate>>(
          stream: _templates,
          builder: (context, snap) {
            final list = snap.data ?? const <MessageTemplate>[];
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('TEMPLATES', style: labelCaps()),
                for (final tpl in list)
                  InputChip(
                    label: Text(tpl.name),
                    selected: tpl.id == _templateId,
                    onPressed: () => _load(tpl),
                    onDeleted: () async {
                      final ok = await confirmDialog(context, title: 'Delete "${tpl.name}"?', confirm: 'Delete', danger: true);
                      if (ok && context.mounted) await Busy.run(context, () => AdminService.deleteTemplate(tpl));
                    },
                  ),
              ]),
            );
          },
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'everyone', label: Text('Everyone')),
                    ButtonSegment(value: 'clients', label: Text('Clients')),
                    ButtonSegment(value: 'artists', label: Text('Artists')),
                  ],
                  selected: {_audience},
                  onSelectionChanged: (v) {
                    setState(() => _audience = v.first);
                    _countReach();
                  },
                ),
                Text(_reach == null ? 'Counting...' : '$_reach accounts', style: t.textTheme.labelLarge),
              ]),
              const SizedBox(height: 14),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title (English)')),
              const SizedBox(height: 10),
              TextField(controller: _body, maxLines: 4, decoration: const InputDecoration(labelText: 'Message (English)')),
              const SizedBox(height: 10),
              TextField(controller: _titleAm, decoration: const InputDecoration(labelText: 'ርዕስ (አማርኛ, optional)')),
              const SizedBox(height: 10),
              TextField(controller: _bodyAm, maxLines: 4, decoration: const InputDecoration(labelText: 'መልዕክት (አማርኛ, optional)')),
              const SizedBox(height: 10),
              TextField(
                controller: _link,
                decoration: const InputDecoration(labelText: 'Opens this page', hintText: '/explore?occasion=bridal'),
              ),
              const SizedBox(height: 16),
              Text('Photos and GIFs (optional)', style: t.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                  'Up to ${CampaignImage.max}. The first one shows large at the top of the email and in the app; '
                  'the rest follow the message. GIFs play in most email apps. Tap a picture to put it first.',
                  style: t.textTheme.bodySmall),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (var i = 0; i < _images.length; i++)
                  _PictureTile(
                    image: _images[i],
                    first: i == 0,
                    onFirst: i == 0
                        ? null
                        : () => setState(() {
                              final x = _images.removeAt(i);
                              _images.insert(0, x);
                            }),
                    onRemove: () => setState(() => _images.removeAt(i)),
                  ),
                if (_uploading)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Center(child: CircularProgressIndicator(value: _progress > 0 ? _progress : null)),
                  )
                else if (_images.length < CampaignImage.max)
                  OutlinedButton.icon(
                    onPressed: _addImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_images.isEmpty ? 'Add photos or GIFs' : 'Add more'),
                  ),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _marketing,
                onChanged: (v) => setState(() => _marketing = v),
                title: const Text('This is marketing (offers, holidays, campaigns)'),
                subtitle: const Text('Marketing only reaches people who opted in. Turn off for service news such as a change to the Terms.'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _email,
                onChanged: (v) => setState(() => _email = v),
                title: Text('Also email it from ${AppConfig.supportEmail}'),
              ),
              if (AppConfig.smsBroadcasts)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _sms,
                  onChanged: (v) => setState(() => _sms = v),
                  title: const Text('Also send as SMS (paid per message)'),
                  subtitle: Text(_bodyAm.text.trim().isNotEmpty
                      ? 'Amharic SMS fit 70 characters per part.'
                      : 'English SMS fit 160 characters per part.'),
                ),
              if (quiet && _marketing)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.honey.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Text('It is quiet hours in Addis (9 PM to 7 AM). Marketing pushes are better sent after 7 AM.'),
                ),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton(onPressed: _saveTemplate, child: const Text('Save as template')),
                OutlinedButton(onPressed: _test, child: const Text('Send a test to me')),
                FilledButton.icon(onPressed: _send, icon: const Icon(Icons.send), label: const Text('Send')),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Text('PREVIEW', style: labelCaps()),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: Listenable.merge([_title, _body]),
          builder: (context, _) => Card(
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_images.isNotEmpty) NetImage(_images.first.url, height: 220, fit: BoxFit.cover),
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(AdminService.fill(_title.text, 'Selam Tesfaye')),
                subtitle: Text(AdminService.fill(_body.text, 'Selam Tesfaye')),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        Text('GETTING-STARTED EMAILS', style: labelCaps()),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text(
                  'Every new account gets a welcome email, then four more in its first week: opening a studio (day 1), '
                  'The Vanity (day 2), how bookings work (day 4) and tips (day 7). Each one fits the person: artist or '
                  'client, English or Amharic, and where her studio stands. They go out between 9 AM and 8 PM Addis, '
                  'at most one a day, and anyone can stop them from the email or in Account.'),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton.icon(
                  onPressed: () => _previewSeries('en'),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Email me every version (English)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _previewSeries('am'),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Email me every version (አማርኛ)'),
                ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _previewSeries(String lang) async {
    final sent = await Busy.run(context, () => AdminService.previewOnboarding(lang: lang));
    if (sent != null && mounted) toast(context, 'Sent $sent emails to you. They arrive in a minute or two.');
  }
}

// ===================================================================== calendar

class CalendarTab extends StatelessWidget {
  final ValueChanged<BroadcastDraft> onUse;
  const CalendarTab({super.key, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final now = addisNow();
    final today = DateTime(now.year, now.month, now.day);
    final events = [...glamEventsForYear(now.year), ...glamEventsForYear(now.year + 1)]
        .where((e) => !e.end.isBefore(today))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return AdminPage(
      title: 'Glam Calendar',
      intro: 'Holidays, fasts and wedding seasons computed from the Ethiopian calendar for the next 12 to 24 months. '
          'Eid dates are estimates until the moon sighting is announced. Tap "Write a broadcast" for ready wording in both languages.',
      children: [
        for (final e in events)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                e.kind == 'season' ? Icons.favorite_border : (e.kind == 'fast' ? Icons.spa_outlined : Icons.celebration_outlined),
              ),
              title: Text('${e.nameEn} · ${e.nameAm}'),
              subtitle: Text(
                '${dayLabelYear(e.start)} · ${ethFull(e.start)}'
                '${e.isSpan ? '\nuntil ${dayLabelYear(e.end)}' : ''}'
                '${e.expected ? '\nestimated date' : ''}',
                style: t.textTheme.bodySmall,
              ),
              isThreeLine: e.isSpan || e.expected,
              trailing: TextButton(onPressed: () => onUse(draftForEvent(e)), child: const Text('Write a broadcast')),
            ),
          ),
      ],
    );
  }
}

/// One picture on a draft: tap to put it first, x to take it off.
class _PictureTile extends StatelessWidget {
  final CampaignImage image;
  final bool first;
  final VoidCallback? onFirst;
  final VoidCallback onRemove;
  const _PictureTile({required this.image, required this.first, required this.onFirst, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(children: [
        Positioned.fill(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onFirst,
            child: NetImage(image.small, radius: BorderRadius.circular(14)),
          ),
        ),
        if (first || image.isGif)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.espresso.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
              child: Text([if (first) 'TOP', if (image.isGif) 'GIF'].join(' · '),
                  style: labelCaps(color: AppColors.milk, size: 10, spacing: 1)),
            ),
          ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton.filledTonal(
            tooltip: 'Take off',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ),
      ]),
    );
  }
}
