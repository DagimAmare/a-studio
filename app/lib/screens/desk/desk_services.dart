import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/studio_service.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../studio_screen.dart' show priceLabel;
import 'desk_screen.dart';

class ServicesTab extends StatelessWidget {
  final Studio studio;
  const ServicesTab({super.key, required this.studio});

  Future<void> _save(BuildContext context, List<ServiceItem> list, String done) =>
      Busy.run(context, () => StudioService.saveServices(list), success: done);

  Future<void> _add(BuildContext context) async {
    final created = await showServiceEditor(context, null);
    if (created == null || !context.mounted) return;
    await _save(context, [...studio.services, created], context.tr('Service added', 'አገልግሎት ታክሏል'));
  }

  Future<void> _edit(BuildContext context, int index) async {
    final updated = await showServiceEditor(context, studio.services[index]);
    if (updated == null || !context.mounted) return;
    final list = [...studio.services];
    list[index] = updated;
    await _save(context, list, context.tr('Saved', 'ተቀምጧል'));
  }

  Future<void> _move(BuildContext context, int index, int delta) async {
    final to = index + delta;
    if (to < 0 || to >= studio.services.length) return;
    final list = [...studio.services];
    final item = list.removeAt(index);
    list.insert(to, item);
    await _save(context, list, context.tr('Order saved', 'ቅደም ተከተሉ ተቀምጧል'));
  }

  Future<void> _delete(BuildContext context, int index) async {
    final svc = studio.services[index];
    final ok = await confirmDialog(context,
        title: context.tr('Delete "${svc.name}"?', '"${svc.name}" ይሰረዝ?'),
        body: context.tr('Past bookings keep their details. To hide it for now, switch it off instead.',
            'ያለፉ ቀጠሮዎች ዝርዝራቸውን ይይዛሉ። ለጊዜው ለመደበቅ ያጥፉት።'),
        confirm: context.tr('Delete', 'ሰርዝ'),
        danger: true);
    if (!ok || !context.mounted) return;
    final list = [...studio.services]..removeAt(index);
    await _save(context, list, context.tr('Deleted', 'ተሰርዟል'));
  }

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    final services = studio.services;
    return DeskPage(
      title: context.tr('Services', 'አገልግሎቶች'),
      intro: context.tr(
          'Set a fixed price, a "from" price for custom work, or no price at all ("price on request"). Duration decides which times clients can book.',
          'ቋሚ ዋጋ፣ ለልዩ ሥራ "ከ" የሚል ዋጋ፣ ወይም ምንም ዋጋ ("ዋጋ በጥያቄ") ያስቀምጡ። የሚፈጀው ጊዜ ደንበኞች የሚይዙትን ሰዓት ይወስናል።'),
      trailing: FilledButton.icon(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('Add service', 'አገልግሎት ጨምር')),
      ),
      children: [
        if (services.isEmpty)
          EmptyState(
            icon: Icons.brush_outlined,
            title: context.tr('No services yet', 'ገና አገልግሎት የለም'),
            body: context.tr('Start from a template like Soft glam or Gel nails.', 'እንደ ሶፍት ግላም ካሉ ናሙናዎች ይጀምሩ።'),
            action: FilledButton(onPressed: () => _add(context), child: Text(context.tr('Add service', 'አገልግሎት ጨምር'))),
          ),
        for (var i = 0; i < services.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _edit(context, i),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(services[i].name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: services[i].active ? null : AppColors.taupe,
                                  )),
                          const SizedBox(height: 4),
                          Text(
                            [
                              optionById(kServiceCategories, services[i].category).label(am),
                              durationLabel(services[i].durationMin),
                              priceLabel(context, services[i]),
                              if (!services[i].active) context.tr('hidden', 'የተደበቀ'),
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Switch(
                    value: services[i].active,
                    onChanged: (v) {
                      final list = [...services];
                      list[i] = services[i].copyWith(active: v);
                      _save(context, list, v ? context.tr('Shown on your page', 'በገጽዎ ይታያል') : context.tr('Hidden', 'ተደብቋል'));
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _edit(context, i);
                      if (v == 'up') _move(context, i, -1);
                      if (v == 'down') _move(context, i, 1);
                      if (v == 'delete') _delete(context, i);
                    },
                    itemBuilder: (c) => [
                      PopupMenuItem(value: 'edit', child: Text(c.tr('Edit', 'አስተካክል'))),
                      if (i > 0) PopupMenuItem(value: 'up', child: Text(c.tr('Move up', 'ወደ ላይ'))),
                      if (i < services.length - 1) PopupMenuItem(value: 'down', child: Text(c.tr('Move down', 'ወደ ታች'))),
                      PopupMenuItem(value: 'delete', child: Text(c.tr('Delete', 'ሰርዝ'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Add or edit one service. Returns null when cancelled.
Future<ServiceItem?> showServiceEditor(BuildContext context, ServiceItem? existing) {
  return showDialog<ServiceItem>(
    context: context,
    builder: (_) => _ServiceEditor(existing: existing),
  );
}

class _ServiceEditor extends StatefulWidget {
  final ServiceItem? existing;
  const _ServiceEditor({this.existing});
  @override
  State<_ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<_ServiceEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _price = TextEditingController(
      text: (widget.existing?.price ?? 0) > 0 ? '${widget.existing!.price}' : '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late String _category = widget.existing?.category ?? 'makeup';
  late int _minutes = widget.existing?.durationMin ?? 90;
  late String _mode = widget.existing?.priceMode ?? 'fixed';
  String? _error;

  static const List<int> _durations = [
    15, 30, 45, 60, 75, 90, 105, 120, 150, 180, 210, 240, 300, 360, 420, 480, 600
  ];

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _useTemplate(ServiceTemplate t) {
    setState(() {
      _name.text = t.name;
      _category = t.category;
      _minutes = t.minutes;
    });
  }

  void _done() {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (name.length < 2) {
      setState(() => _error = context.tr('Give the service a name.', 'ለአገልግሎቱ ስም ይስጡ።'));
      return;
    }
    if (_mode != 'hidden' && price <= 0) {
      setState(() => _error = context.tr('Enter a price, or choose "Price on request".', 'ዋጋ ያስገቡ፣ ወይም "ዋጋ በጥያቄ" ይምረጡ።'));
      return;
    }
    final base = widget.existing ??
        ServiceItem(
          id: StudioService.newServiceId(),
          name: name,
          category: _category,
          durationMin: _minutes,
          priceMode: _mode,
          price: price,
        );
    Navigator.pop(
      context,
      base.copyWith(
        name: name,
        category: _category,
        durationMin: _minutes,
        priceMode: _mode,
        price: _mode == 'hidden' ? 0 : price,
        description: _desc.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    final durations = {..._durations, _minutes}.toList()..sort();
    return AlertDialog(
      title: Text(widget.existing == null ? context.tr('New service', 'አዲስ አገልግሎት') : context.tr('Edit service', 'አገልግሎት አስተካክል')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.existing == null) ...[
                Text(context.tr('Start from a template', 'ከናሙና ይጀምሩ'), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in kServiceTemplates)
                    ActionChip(label: Text(t.name), onPressed: () => _useTemplate(t)),
                ]),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: context.tr('Service name', 'የአገልግሎቱ ስም')),
              ),
              const SizedBox(height: 12),
              SelectField<String>(
                label: context.tr('Category', 'ዘርፍ'),
                value: _category,
                items: [for (final c in kServiceCategories) (c.id, c.label(am))],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              SelectField<int>(
                label: context.tr('How long it takes (per person)', 'የሚፈጀው ጊዜ (ለአንድ ሰው)'),
                value: _minutes,
                items: [for (final m in durations) (m, durationLabel(m))],
                onChanged: (v) => setState(() => _minutes = v ?? _minutes),
              ),
              const SizedBox(height: 16),
              Text(context.tr('Price', 'ዋጋ'), style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'fixed', label: Text(context.tr('Fixed', 'ቋሚ'))),
                  ButtonSegment(value: 'from', label: Text(context.tr('Starting from', 'ከ...ጀምሮ'))),
                  ButtonSegment(value: 'hidden', label: Text(context.tr('On request', 'በጥያቄ'))),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              const SizedBox(height: 12),
              if (_mode != 'hidden')
                TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _mode == 'from' ? context.tr('Starting price (Birr)', 'መነሻ ዋጋ (ብር)') : context.tr('Price (Birr)', 'ዋጋ (ብር)'),
                    prefixText: 'Br ',
                  ),
                )
              else
                Text(
                  context.tr('Clients see "Price on request" and you agree the price in chat.',
                      'ደንበኞች "ዋጋ በጥያቄ" ያያሉ፣ ዋጋውን በመልዕክት ይስማማሉ።'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.tr('What is included (optional)', 'ምን እንደሚጨምር (አማራጭ)'),
                  hintText: context.tr('Lashes included, skin prep, touch-up kit...', 'ሽፋሽፍት ይጨምራል...'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Cancel', 'ይቅር'))),
        FilledButton(onPressed: _done, child: Text(context.tr('Save', 'አስቀምጥ'))),
      ],
    );
  }
}
