import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../services/studio_service.dart';
import '../../widgets/common.dart';
import '../../widgets/video_view.dart';
import 'backstage_screen.dart';

const Map<String, String> kBadgeLabels = {
  'top_rated': 'Top rated',
  'bridal': 'Bridal specialist',
  'fast': 'Fast responder',
  'certified': 'A Studio Certified',
};

// ===================================================================== verification

class VerificationTab extends StatefulWidget {
  const VerificationTab({super.key});
  @override
  State<VerificationTab> createState() => _VerificationTabState();
}

class _VerificationTabState extends State<VerificationTab> {
  late final Stream<List<Studio>> _studios = AdminService.allStudios();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Studio>>(
      stream: _studios,
      builder: (context, snap) {
        final pending = (snap.data ?? const <Studio>[]).where((s) => s.verification == 'pending').toList()
          ..sort((a, b) => (a.publishedAt ?? DateTime(2100)).compareTo(b.publishedAt ?? DateTime(2100)));
        return AdminPage(
          title: 'Verification queue',
          intro: 'Check the ID or Fayda photo and the work video against the portfolio, then approve or reject with a reason. '
              'Both files are deleted from the private folder as soon as you decide.',
          children: [
            if (!snap.hasData)
              const Loading()
            else if (pending.isEmpty)
              const EmptyState(icon: Icons.verified_outlined, title: 'Nobody is waiting')
            else
              for (final s in pending) _VerifyCard(studio: s),
          ],
        );
      },
    );
  }
}

class _VerifyCard extends StatefulWidget {
  final Studio studio;
  const _VerifyCard({required this.studio});
  @override
  State<_VerifyCard> createState() => _VerifyCardState();
}

class _VerifyCardState extends State<_VerifyCard> {
  late final Stream<Map<String, dynamic>> _files = StudioService.verificationFiles(widget.studio.uid);

  Future<void> _view(String path, bool video) async {
    final url = await Busy.run(context, () => MediaService.privateObjectUrl(path), error: AuthService.friendlyError);
    if (url == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: video
                    ? AspectRatio(aspectRatio: 9 / 16, child: WebVideo(url, autoplay: true))
                    : InteractiveViewer(child: NetImage(url, fit: BoxFit.contain)),
              ),
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _approve() async {
    final ok = await confirmDialog(context,
        title: 'Verify ${widget.studio.name}?', body: 'The Verified badge appears on the page right away.', confirm: 'Verify');
    if (!ok || !mounted) return;
    await Busy.run(context, () async {
      await AdminService.setVerification(widget.studio, 'verified');
      await AdminService.clearVerificationFiles(widget.studio.uid);
    }, success: 'Verified');
  }

  Future<void> _reject() async {
    final reason = await textPrompt(context,
        title: 'Reason for ${widget.studio.name}',
        hint: 'She sees this. Example: the ID photo is blurry, please upload a clearer one.',
        required: true,
        confirm: 'Send');
    if (reason == null || !mounted) return;
    await Busy.run(context, () async {
      await AdminService.setVerification(widget.studio, 'rejected', reason: reason);
      await AdminService.clearVerificationFiles(widget.studio.uid);
    }, success: 'Sent back with your reason');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.studio;
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _files,
          builder: (context, snap) {
            final files = snap.data ?? const <String, dynamic>{};
            final id = files['id'] is String ? files['id'] as String : '';
            final work = files['work'] is String ? files['work'] as String : '';
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(url: s.avatarUrl, name: s.name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: t.textTheme.titleMedium),
                    Text('@${s.handle} · live since ${s.publishedAt == null ? '?' : dayLabelYear(s.publishedAt!)}',
                        style: t.textTheme.bodySmall),
                  ]),
                ),
                TextButton(onPressed: () => context.go('/${s.handle}'), child: const Text('Open page')),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton.icon(
                  onPressed: id.isEmpty ? null : () => _view(id, false),
                  icon: const Icon(Icons.badge_outlined),
                  label: Text(id.isEmpty ? 'No ID uploaded yet' : 'View ID'),
                ),
                OutlinedButton.icon(
                  onPressed: work.isEmpty ? null : () => _view(work, true),
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(work.isEmpty ? 'No work video yet' : 'View work video'),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 10, children: [
                FilledButton(onPressed: _approve, child: const Text('Verify')),
                OutlinedButton(onPressed: _reject, child: const Text('Reject with reason')),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}

// ===================================================================== artists

class ArtistsTab extends StatefulWidget {
  const ArtistsTab({super.key});
  @override
  State<ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<ArtistsTab> {
  late final Stream<List<Studio>> _studios = AdminService.allStudios();
  final _q = TextEditingController();
  String _status = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _badges(Studio s) async {
    final chosen = {...s.badges};
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Badges for ${s.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final e in kBadgeLabels.entries)
              CheckboxListTile(
                value: chosen.contains(e.key),
                onChanged: (v) => set(() => v == true ? chosen.add(e.key) : chosen.remove(e.key)),
                title: Text(e.value),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await Busy.run(context, () => AdminService.setBadges(s, chosen.toList()), success: 'Badges saved');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return StreamBuilder<List<Studio>>(
      stream: _studios,
      builder: (context, snap) {
        final q = _q.text.trim().toLowerCase();
        final list = (snap.data ?? const <Studio>[])
            .where((s) => _status.isEmpty || s.status == _status)
            .where((s) => q.isEmpty || '${s.name} ${s.handle} ${s.whatsapp}'.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));
        return AdminPage(
          title: 'Artists',
          children: [
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Name, handle or phone'),
                ),
              ),
              for (final f in const [('', 'All'), ('live', 'Live'), ('draft', 'Draft'), ('suspended', 'Paused')])
                ChoiceChip(label: Text(f.$2), selected: _status == f.$1, onSelected: (_) => setState(() => _status = f.$1)),
            ]),
            const SizedBox(height: 12),
            if (!snap.hasData) const Loading(),
            for (final s in list)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(children: [
                    Avatar(url: s.avatarUrl, name: s.name, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, style: t.textTheme.titleSmall),
                        Text(
                          [
                            '@${s.handle}',
                            s.status,
                            'verification: ${s.verification}',
                            if (s.featured) 'featured',
                            if (s.badges.isNotEmpty) s.badges.map((b) => kBadgeLabels[b] ?? b).join(', '),
                            if (s.ratingCount > 0) '${s.ratingAvg.toStringAsFixed(1)}★ (${s.ratingCount})',
                          ].join(' · '),
                          style: t.textTheme.bodySmall,
                        ),
                      ]),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        switch (v) {
                          case 'open':
                            context.go('/${s.handle}');
                            break;
                          case 'feature':
                            await Busy.run(context, () => AdminService.setFeatured(s, !s.featured),
                                success: s.featured ? 'No longer featured' : 'Featured on the home page');
                            break;
                          case 'badges':
                            await _badges(s);
                            break;
                          case 'verify':
                            await Busy.run(context, () => AdminService.setVerification(s, 'verified'), success: 'Verified');
                            break;
                          case 'pause':
                            final ok = await confirmDialog(context,
                                title: 'Pause ${s.name}?',
                                body: 'Her page goes offline and she cannot publish until you restore it.',
                                confirm: 'Pause',
                                danger: true);
                            if (ok && context.mounted) {
                              await Busy.run(context, () => AdminService.setStudioStatus(s, 'suspended'), success: 'Paused');
                            }
                            break;
                          case 'restore':
                            await Busy.run(context, () => AdminService.setStudioStatus(s, 'draft'),
                                success: 'Restored as a draft; she can publish again');
                            break;
                          case 'whatsapp':
                            openExternal('https://wa.me/${whatsappDigits(s.whatsapp)}');
                            break;
                        }
                      },
                      itemBuilder: (c) => [
                        const PopupMenuItem(value: 'open', child: Text('Open page')),
                        PopupMenuItem(value: 'feature', child: Text(s.featured ? 'Remove from featured' : 'Feature on home page')),
                        const PopupMenuItem(value: 'badges', child: Text('Badges')),
                        if (!s.isVerified) const PopupMenuItem(value: 'verify', child: Text('Mark verified')),
                        if (s.status != 'suspended') const PopupMenuItem(value: 'pause', child: Text('Pause studio')),
                        if (s.status == 'suspended') const PopupMenuItem(value: 'restore', child: Text('Restore studio')),
                        if (s.whatsapp.isNotEmpty) const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp her')),
                      ],
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

// ===================================================================== people

class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key});
  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  late final Stream<List<UserProfile>> _users = AdminService.users();
  final _q = TextEditingController();
  String _role = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return StreamBuilder<List<UserProfile>>(
      stream: _users,
      builder: (context, snap) {
        final q = _q.text.trim().toLowerCase();
        final list = (snap.data ?? const <UserProfile>[])
            .where((u) => _role.isEmpty || u.role == _role)
            .where((u) => q.isEmpty || '${u.name} ${u.email} ${u.phone} ${u.uid}'.toLowerCase().contains(q))
            .toList();
        return AdminPage(
          title: 'People',
          intro: '${snap.data?.length ?? 0} accounts.',
          children: [
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Name, email, phone or ID'),
                ),
              ),
              for (final f in const [('', 'Everyone'), ('client', 'Clients'), ('artist', 'Artists')])
                ChoiceChip(label: Text(f.$2), selected: _role == f.$1, onSelected: (_) => setState(() => _role = f.$1)),
            ]),
            const SizedBox(height: 12),
            if (!snap.hasData) const Loading(),
            for (final u in list.take(400))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Avatar(url: u.photoUrl, name: u.name, size: 40),
                  title: Text(u.name.isEmpty ? '(no name)' : u.name),
                  subtitle: Text(
                    [
                      u.role,
                      u.email,
                      if (u.phone.isNotEmpty) u.phone,
                      if (u.suspended) 'PAUSED',
                      if (u.marketing) 'marketing on',
                      'joined ${timeAgo(u.createdAt)}',
                    ].join(' · '),
                    style: t.textTheme.bodySmall,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'mail') openExternal('mailto:${u.email}');
                      if (v == 'call') openExternal('tel:${u.phone}');
                      if (v == 'copy') copyText(context, u.uid);
                      if (v == 'pause') {
                        final ok = await confirmDialog(context,
                            title: 'Pause ${u.name}?',
                            body: 'They can still sign in, but cannot book, message or post.',
                            confirm: 'Pause',
                            danger: true);
                        if (ok && context.mounted) {
                          await Busy.run(context, () => AdminService.setUserStatus(u, 'suspended'), success: 'Paused');
                        }
                      }
                      if (v == 'restore') {
                        await Busy.run(context, () => AdminService.setUserStatus(u, 'active'), success: 'Restored');
                      }
                    },
                    itemBuilder: (c) => [
                      if (u.email.isNotEmpty) const PopupMenuItem(value: 'mail', child: Text('Email')),
                      if (u.phone.isNotEmpty) const PopupMenuItem(value: 'call', child: Text('Call')),
                      const PopupMenuItem(value: 'copy', child: Text('Copy user ID')),
                      if (!u.suspended) const PopupMenuItem(value: 'pause', child: Text('Pause account')),
                      if (u.suspended) const PopupMenuItem(value: 'restore', child: Text('Restore account')),
                    ],
                  ),
                ),
              ),
            if (list.length > 400)
              Text('Showing the first 400. Search to narrow it down.', style: t.textTheme.bodySmall),
          ],
        );
      },
    );
  }
}

/// Used by the reports tab to open what was reported.
String? reportTargetLink(String type, String id, String label) {
  if (type == 'listing') return '/shop/$id';
  if (type == 'studio' && label.startsWith('@')) return '/${label.substring(1)}';
  if (type == 'booking') return '/bookings/$id';
  return null;
}
