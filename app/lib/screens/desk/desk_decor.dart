import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/studio_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../studio_screen.dart' show priceLabel;
import 'desk_screen.dart';

/// "Decor your studio": colours, accent and headline font for the public
/// page. The layout stays the same for every artist.
class DecorTab extends StatefulWidget {
  final Studio studio;
  const DecorTab({super.key, required this.studio});
  @override
  State<DecorTab> createState() => _DecorTabState();
}

class _DecorTabState extends State<DecorTab> {
  late String _theme = widget.studio.decor.theme;
  late String _accent = widget.studio.decor.accent;
  late String _font = widget.studio.decor.font;

  bool get _dirty =>
      _theme != widget.studio.decor.theme ||
      _accent != widget.studio.decor.accent ||
      _font != widget.studio.decor.font;

  Future<void> _save() => Busy.run(
        context,
        () => StudioService.update({
          'decor': StudioDecor(theme: _theme, accent: _accent, font: _font).toMap(),
        }, log: 'decor_update'),
        success: context.tr('Your page has its new look', 'ገጽዎ አዲስ ገጽታ አግኝቷል'),
      );

  void _reset() => setState(() {
        _theme = 'milk';
        _accent = 'rouge';
        _font = 'bodoni';
      });

  @override
  Widget build(BuildContext context) {
    final palette = paletteById(_theme);
    final accent = accentById(_accent);
    final font = fontById(_font);
    return DeskPage(
      title: context.tr('Decor your studio', 'ስቱዲዮዎን ያስውቡ'),
      intro: context.tr('Pick the colours and headline style of your page. Every studio keeps the same easy layout, so clients always know where to tap.',
          'የገጽዎን ቀለሞች እና የርዕስ ዘይቤ ይምረጡ። ደንበኞች የት እንደሚነኩ እንዲያውቁ የሁሉም ስቱዲዮ አቀማመጥ አንድ ነው።'),
      trailing: FilledButton(onPressed: _dirty ? _save : null, child: Text(context.tr('Save', 'አስቀምጥ'))),
      children: [
        DeskCard(
          title: context.tr('Page colour', 'የገጽ ቀለም'),
          children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final p in kStudioPalettes)
                _Swatch(
                  selected: p.id == _theme,
                  label: p.label,
                  colors: [p.background, p.surface, p.text],
                  onTap: () => setState(() => _theme = p.id),
                ),
            ]),
          ],
        ),
        DeskCard(
          title: context.tr('Accent', 'ዋና ቀለም'),
          children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final a in kStudioAccents)
                _Swatch(
                  selected: a.id == _accent,
                  label: a.label,
                  colors: [palette.dark ? a.onDark : a.onLight],
                  onTap: () => setState(() => _accent = a.id),
                ),
            ]),
          ],
        ),
        DeskCard(
          title: context.tr('Headline style', 'የርዕስ ዘይቤ'),
          children: [
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final f in kStudioFonts)
                ChoiceChip(
                  selected: f.id == _font,
                  onSelected: (_) => setState(() => _font = f.id),
                  label: Text(f.label,
                      style: TextStyle(fontFamily: f.family, fontStyle: f.style, fontSize: 17)),
                ),
            ]),
          ],
        ),
        Text(context.tr('PREVIEW', 'ቅድመ እይታ'), style: labelCaps()),
        const SizedBox(height: 10),
        Theme(
          data: buildAppTheme(palette: palette, accent: accent, font: font),
          child: _Preview(studio: widget.studio),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, children: [
          TextButton(onPressed: _reset, child: Text(context.tr('Back to the A Studio default', 'ወደ ነባሪው ተመለስ'))),
          TextButton(
            onPressed: () => context.go('/${widget.studio.handle}'),
            child: Text(context.tr('Open my page', 'ገጼን ክፈት')),
          ),
        ]),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final bool selected;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const _Swatch({required this.selected, required this.label, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 112,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 44,
              child: Row(children: [for (final c in colors) Expanded(child: ColoredBox(color: c))]),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ]),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final Studio studio;
  const _Preview({required this.studio});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final svc = studio.activeServices.isEmpty ? null : studio.activeServices.first;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Avatar(url: studio.avatarUrl, name: studio.name, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(studio.name, style: t.textTheme.headlineMedium),
                if (studio.tagline.isNotEmpty) Text(studio.tagline, style: t.textTheme.bodyMedium),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              title: Text(svc?.name ?? context.tr('Soft glam', 'ሶፍት ግላም')),
              subtitle: Text(svc == null ? 'Br 2,500' : priceLabel(context, svc)),
              trailing: FilledButton(onPressed: () {}, child: Text(context.tr('Book', 'ይያዙ'))),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            OutlinedButton(onPressed: () {}, child: const Text('WhatsApp')),
            OutlinedButton(onPressed: () {}, child: const Text('Telegram')),
          ]),
        ],
      ),
    );
  }
}
