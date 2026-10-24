import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/catalog.dart';
import '../../core/validators.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../services/studio_service.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../widgets/video_view.dart';
import 'desk_screen.dart';

class ProfileTab extends StatefulWidget {
  final Studio studio;
  const ProfileTab({super.key, required this.studio});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Studio get s => widget.studio;
  late final _name = TextEditingController(text: s.name);
  late final _tagline = TextEditingController(text: s.tagline);
  late final _bio = TextEditingController(text: s.bio);
  late final _area = TextEditingController(text: s.studioArea);
  late final _whatsapp = TextEditingController(text: s.whatsapp);
  late final _telegram = TextEditingController(text: s.telegram);
  late final Set<String> _specialties = {...s.specialties};
  late final Set<String> _subCities = {...s.subCities};
  late bool _atStudio = s.atStudio;
  late bool _home = s.homeVisits;
  late bool _venue = s.venueVisits;
  String _uploading = '';
  double _progress = 0;

  @override
  void dispose() {
    for (final c in [_name, _tagline, _bio, _area, _whatsapp, _telegram]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    try {
      final list = await MediaService.pickImages(multiple: false);
      if (list.isEmpty || !mounted) return;
      setState(() {
        _uploading = 'avatar';
        _progress = 0;
      });
      final old = s.avatarUrl;
      final up = await MediaService.upload(list.first, onProgress: (f) {
        if (mounted) setState(() => _progress = f);
      });
      await StudioService.update({'avatarUrl': up.url}, log: 'studio_avatar');
      if (old.isNotEmpty) MediaService.delete(old);
      if (mounted) toast(context, context.tr('Photo updated', 'ፎቶ ተቀይሯል'));
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = '');
    }
  }

  Future<void> _uploadCover({required bool video}) async {
    try {
      PickedMedia? media;
      if (video) {
        media = await MediaService.pickVideo();
      } else {
        final list = await MediaService.pickImages(multiple: false);
        media = list.isEmpty ? null : list.first;
      }
      if (media == null || !mounted) return;
      setState(() {
        _uploading = 'cover';
        _progress = 0;
      });
      final old = s.coverUrl;
      final up = await MediaService.upload(media, onProgress: (f) {
        if (mounted) setState(() => _progress = f);
      });
      await StudioService.update({'coverUrl': up.url, 'coverType': video ? 'video' : 'image'}, log: 'studio_cover');
      if (old.isNotEmpty) MediaService.delete(old);
      if (mounted) toast(context, context.tr('Cover updated', 'ሽፋኑ ተቀይሯል'));
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = '');
    }
  }

  Future<void> _changeHandle() async {
    final result = await showDialog<String>(context: context, builder: (_) => _HandleDialog(current: s.handle));
    if (result == null || result == s.handle || !mounted) return;
    await Busy.run(context, () => StudioService.changeHandle(s.handle, result),
        success: context.tr('Your new link is ready. Update it in your bios.', 'አዲሱ ሊንክዎ ዝግጁ ነው። በመግለጫዎችዎ ላይ ያዘምኑት።'));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      toast(context, context.tr('Your studio needs a name.', 'ስቱዲዮዎ ስም ያስፈልገዋል።'));
      return;
    }
    if (!_atStudio && !_home && !_venue) {
      toast(context, context.tr('Choose at least one place you work.', 'ቢያንስ አንድ የሥራ ቦታ ይምረጡ።'));
      return;
    }
    final wa = _whatsapp.text.trim();
    final tg = telegramUsername(_telegram.text);
    await Busy.run(
      context,
      () => StudioService.update({
        'name': name,
        'tagline': _tagline.text.trim(),
        'bio': _bio.text.trim(),
        'specialties': _specialties.toList(),
        'subCities': _subCities.toList(),
        'workModes': {'studio': _atStudio, 'home': _home, 'venue': _venue},
        'studioArea': _area.text.trim(),
        'whatsapp': wa.isEmpty ? '' : (normalizeEthiopianPhone(wa) ?? wa),
        'telegram': tg,
      }, log: 'studio_profile'),
      success: context.tr('Saved', 'ተቀምጧል'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    final t = Theme.of(context);
    return DeskPage(
      title: context.tr('Profile & contact', 'መገለጫ እና አድራሻ'),
      trailing: FilledButton(onPressed: _save, child: Text(context.tr('Save', 'አስቀምጥ'))),
      children: [
        DeskCard(
          title: context.tr('Photos', 'ፎቶዎች'),
          children: [
            Row(children: [
              Avatar(url: s.avatarUrl, name: s.name, size: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('Profile photo', 'የመገለጫ ፎቶ'), style: t.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: _uploading.isEmpty ? _uploadAvatar : null,
                    child: Text(s.avatarUrl.isEmpty ? context.tr('Upload', 'ጫን') : context.tr('Change', 'ቀይር')),
                  ),
                ]),
              ),
            ]),
            if (_uploading == 'avatar') ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            ],
            const Divider(height: 32),
            Text(context.tr('Cover: a photo, or a short reel that plays silently', 'ሽፋን፡ ፎቶ ወይም በዝምታ የሚጫወት አጭር ቪዲዮ'),
                style: t.textTheme.titleSmall),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: s.coverUrl.isEmpty
                    ? Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.petal, AppColors.latte]),
                        ),
                      )
                    : (s.coverType == 'video'
                        ? WebVideo(s.coverUrl, autoplay: true, muted: true, loop: true, controls: false, cover: true)
                        : NetImage(s.coverUrl)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton.icon(
                onPressed: _uploading.isEmpty ? () => _uploadCover(video: false) : null,
                icon: const Icon(Icons.image_outlined),
                label: Text(context.tr('Cover photo', 'የሽፋን ፎቶ')),
              ),
              OutlinedButton.icon(
                onPressed: _uploading.isEmpty ? () => _uploadCover(video: true) : null,
                icon: const Icon(Icons.movie_outlined),
                label: Text(context.tr('Cover reel (10 seconds)', 'የሽፋን ቪዲዮ (10 ሰከንድ)')),
              ),
            ]),
            if (_uploading == 'cover') ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            ],
          ],
        ),
        DeskCard(
          title: context.tr('Your link', 'ሊንክዎ'),
          children: [
            Row(children: [
              Expanded(child: SelectableText(AppConfig.studioLink(s.handle).replaceFirst('https://', ''))),
              TextButton(onPressed: _changeHandle, child: Text(context.tr('Change', 'ቀይር'))),
            ]),
            Text(
              context.tr('If you change it, the old link stops working.', 'ከቀየሩት የድሮው ሊንክ መሥራት ያቆማል።'),
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
        DeskCard(
          title: context.tr('About you', 'ስለ እርስዎ'),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.tr('Studio or artist name', 'የስቱዲዮ ወይም የባለሙያ ስም')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagline,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: context.tr('One line about your style', 'ስለ ዘይቤዎ አንድ መስመር'),
                hintText: context.tr('Soft, skin-first bridal glam in Bole', 'በቦሌ ለስላሳ የሙሽራ ግላም'),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _bio,
              maxLines: 5,
              maxLength: 800,
              decoration: InputDecoration(
                labelText: context.tr('About', 'ስለ'),
                hintText: context.tr('Your training, the brands in your kit, what clients love...', 'ሥልጠናዎ፣ የሚጠቀሙባቸው ብራንዶች...'),
              ),
            ),
            const SizedBox(height: 8),
            Text(context.tr('Specialties (up to 3)', 'ልዩ ሙያዎች (እስከ 3)'), style: t.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in kServiceCategories)
                FilterChip(
                  label: Text(c.label(am)),
                  selected: _specialties.contains(c.id),
                  onSelected: (on) => setState(() {
                    if (on && _specialties.length < 3) _specialties.add(c.id);
                    if (!on) _specialties.remove(c.id);
                  }),
                ),
            ]),
          ],
        ),
        DeskCard(
          title: context.tr('Where you work', 'የት ይሠራሉ'),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _atStudio,
              onChanged: (v) => setState(() => _atStudio = v),
              title: Text(context.tr('At my studio or salon', 'በስቱዲዮዬ ወይም በሳሎኔ')),
            ),
            if (_atStudio)
              TextField(
                controller: _area,
                decoration: InputDecoration(
                  labelText: context.tr('Area and landmark (shown to clients)', 'አካባቢ እና መለያ ምልክት (ለደንበኞች ይታያል)'),
                  hintText: context.tr('Bole, near Edna Mall', 'ቦሌ፣ ኤድና ሞል አጠገብ'),
                  helperText: context.tr('Never your full home address.', 'ሙሉ የቤት አድራሻዎን በጭራሽ አይጻፉ።'),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _home,
              onChanged: (v) => setState(() => _home = v),
              title: Text(context.tr('Home visits', 'ቤት ድረስ')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _venue,
              onChanged: (v) => setState(() => _venue = v),
              title: Text(context.tr('Venues and hotels', 'የዝግጅት ቦታዎች እና ሆቴሎች')),
            ),
            const SizedBox(height: 8),
            Text(context.tr('Sub-cities you cover', 'የሚሸፍኗቸው ክፍለ ከተሞች'), style: t.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in kSubCities)
                FilterChip(
                  label: Text(c.label(am)),
                  selected: _subCities.contains(c.id),
                  onSelected: (on) => setState(() => on ? _subCities.add(c.id) : _subCities.remove(c.id)),
                ),
            ]),
          ],
        ),
        DeskCard(
          title: context.tr('How clients reach you', 'ደንበኞች እንዴት ያግኙዎት'),
          children: [
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.tr('WhatsApp number', 'የዋትስአፕ ቁጥር'), hintText: '0911 234 567'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telegram,
              decoration: InputDecoration(labelText: context.tr('Telegram username', 'የቴሌግራም ስም'), hintText: '@yourname'),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Clients can also message you inside A Studio. Only WhatsApp and Telegram show on your page.',
                  'ደንበኞች በኤ ስቱዲዮ ውስጥም መልዕክት ሊልኩልዎ ይችላሉ። በገጽዎ ላይ የሚታዩት ዋትስአፕ እና ቴሌግራም ብቻ ናቸው።'),
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _save, child: Text(context.tr('Save changes', 'ለውጦቹን አስቀምጥ'))),
        ),
      ],
    );
  }
}

/// Picks a new handle and checks it is free.
class _HandleDialog extends StatefulWidget {
  final String current;
  const _HandleDialog({required this.current});
  @override
  State<_HandleDialog> createState() => _HandleDialogState();
}

class _HandleDialogState extends State<_HandleDialog> {
  late final _ctrl = TextEditingController(text: widget.current);
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final h = normalizeHandle(_ctrl.text);
    final problem = handleProblem(h);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (h == widget.current) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final free = await StudioService.handleAvailable(h);
      if (!mounted) return;
      if (free) {
        Navigator.pop(context, h);
      } else {
        setState(() => _error = context.tr('That link is taken. Try another.', 'ይህ ሊንክ ተይዟል። ሌላ ይሞክሩ።'));
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('Could not check. Try again.', 'ማረጋገጥ አልተቻለም።'));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Change your link', 'ሊንክዎን ይቀይሩ')),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _check(),
          decoration: InputDecoration(
            prefixText: 'astudio.hepius.co/',
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Cancel', 'ይቅር'))),
        FilledButton(onPressed: _checking ? null : _check, child: Text(context.tr('Use this link', 'ይህን ተጠቀም'))),
      ],
    );
  }
}
