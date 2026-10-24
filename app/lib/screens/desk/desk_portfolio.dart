import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../services/studio_service.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/media_viewer.dart';
import 'desk_screen.dart';

class PortfolioTab extends StatefulWidget {
  final Studio studio;
  const PortfolioTab({super.key, required this.studio});
  @override
  State<PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<PortfolioTab> {
  late final Stream<List<Look>> _looks = StudioService.looksFor(widget.studio.uid);
  String _occasion = '';
  String _status = '';
  double? _progress;

  bool get _busy => _status.isNotEmpty;

  Future<void> _addPhotos() async {
    try {
      final picked = await MediaService.pickImages();
      if (picked.isEmpty || !mounted) return;
      for (var i = 0; i < picked.length; i++) {
        setState(() {
          _status = context.tr('Uploading photo ${i + 1} of ${picked.length}', 'ፎቶ ${i + 1} ከ${picked.length} በመጫን ላይ');
          _progress = 0;
        });
        final up = await MediaService.upload(picked[i], onProgress: (f) {
          if (mounted) setState(() => _progress = f);
        });
        await StudioService.addLook(widget.studio, up, occasion: _occasion);
      }
      if (mounted) toast(context, context.tr('Added to your portfolio', 'ወደ ሥራዎችዎ ታክሏል'));
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _status = '';
          _progress = null;
        });
      }
    }
  }

  Future<void> _addVideo() async {
    try {
      final video = await MediaService.pickVideo();
      if (video == null || !mounted) return;
      setState(() {
        _status = context.tr('Uploading video', 'ቪዲዮ በመጫን ላይ');
        _progress = 0;
      });
      final up = await MediaService.uploadVideoWithPoster(video, onProgress: (f) {
        if (mounted) setState(() => _progress = f);
      });
      await StudioService.addLook(widget.studio, up, occasion: _occasion);
      if (mounted) toast(context, context.tr('Video added', 'ቪዲዮ ታክሏል'));
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _status = '';
          _progress = null;
        });
      }
    }
  }

  Future<void> _edit(Look look) async {
    final caption = TextEditingController(text: look.caption);
    var occasion = look.occasion;
    final action = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(c.tr('Edit look', 'ሥራውን አስተካክል')),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: caption,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: c.tr('Caption', 'መግለጫ'),
                  hintText: c.tr('Soft glam for a Bole wedding', 'ለቦሌ ሠርግ ሶፍት ግላም'),
                ),
              ),
              const SizedBox(height: 12),
              SelectField<String>(
                label: c.tr('Occasion', 'ዝግጅት'),
                value: occasion,
                items: [('', c.tr('None', 'የለም')), for (final o in kOccasions) (o.id, o.label(c.isAm))],
                onChanged: (v) => set(() => occasion = v ?? ''),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, 'delete'),
              child: Text(c.tr('Delete', 'ሰርዝ'), style: TextStyle(color: Theme.of(c).colorScheme.error)),
            ),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(c.tr('Cancel', 'ይቅር'))),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: Text(c.tr('Save', 'አስቀምጥ'))),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'save') {
      await Busy.run(context, () => StudioService.updateLook(look.id, caption: caption.text.trim(), occasion: occasion),
          success: context.tr('Saved', 'ተቀምጧል'));
    } else if (action == 'delete') {
      final ok = await confirmDialog(context,
          title: context.tr('Delete this look?', 'ይህ ሥራ ይሰረዝ?'), confirm: context.tr('Delete', 'ሰርዝ'), danger: true);
      if (ok && mounted) {
        await Busy.run(context, () => StudioService.deleteLook(look), success: context.tr('Deleted', 'ተሰርዟል'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return StreamBuilder<List<Look>>(
      stream: _looks,
      builder: (context, snap) {
        final looks = snap.data ?? const <Look>[];
        return DeskPage(
          title: context.tr('Portfolio', 'ሥራዎቼ'),
          intro: context.tr(
              'Photos and short videos of your real work. Tag the occasion so brides and graduates find you. Only post a client\'s photo if she agreed.',
              'የእውነተኛ ሥራዎ ፎቶዎች እና አጫጭር ቪዲዮዎች። ሙሽሮች እና ተመራቂዎች እንዲያገኙዎ ዝግጅቱን ይጥቀሱ። የደንበኛን ፎቶ የሚለጥፉት ከፈቀደች ብቻ ነው።'),
          children: [
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FilledButton.icon(
                onPressed: _busy ? null : _addPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(context.tr('Add photos', 'ፎቶዎች ጨምር')),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _addVideo,
                icon: const Icon(Icons.video_call_outlined),
                label: Text(context.tr('Add a video', 'ቪዲዮ ጨምር')),
              ),
              SizedBox(
                width: 230,
                child: SelectField<String>(
                  label: context.tr('Tag new uploads as', 'አዲሶቹን እንደ ምን ይጥቀሱ'),
                  value: _occasion,
                  items: [('', context.tr('No tag', 'ያለ ምልክት')), for (final o in kOccasions) (o.id, o.label(am))],
                  onChanged: (v) => setState(() => _occasion = v ?? ''),
                ),
              ),
            ]),
            if (_busy) ...[
              const SizedBox(height: 14),
              Text(_status),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: (_progress ?? 0) > 0 ? _progress : null),
            ],
            const SizedBox(height: 8),
            Text(
              context.tr('Photos are resized on your phone before upload. Videos up to 64 MB (about 1 minute).',
                  'ፎቶዎች ከመጫናቸው በፊት ይጨመቃሉ። ቪዲዮዎች እስከ 64 ሜባ (1 ደቂቃ ገደማ)።'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            if (looks.isEmpty && snap.connectionState != ConnectionState.waiting)
              EmptyState(
                icon: Icons.photo_library_outlined,
                title: context.tr('Show your best work', 'ምርጥ ሥራዎን ያሳዩ'),
                body: context.tr('Pages with 6 or more looks get far more bookings.', '6 እና ከዚያ በላይ ሥራ ያላቸው ገጾች ብዙ ቀጠሮ ያገኛሉ።'),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 4 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 4 / 5,
                ),
                itemCount: looks.length,
                itemBuilder: (context, i) {
                  final l = looks[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      LookTile(
                        look: l,
                        showArtist: false,
                        onTap: () => openMediaViewer(
                          context,
                          [for (final x in looks) MediaItem(x.url, isVideo: x.isVideo, caption: x.caption)],
                          i,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: IconButton.filledTonal(
                          tooltip: context.tr('Edit', 'አስተካክል'),
                          onPressed: () => _edit(l),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ),
                      if (l.occasion.isNotEmpty)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Pill(optionById(kOccasions, l.occasion).label(am)),
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
