import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/validators.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../services/studio_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/gate.dart';

/// Studio setup wizard: name and link, what she does, contact, services.
class DeskSetupScreen extends StatelessWidget {
  const DeskSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SignedInGate(builder: (context) {
      final s = Session.instance;
      if (!s.studioLoaded) return const Loading();
      if (s.studio != null) {
        return EmptyState(
          icon: Icons.storefront_outlined,
          title: context.tr('Your studio is already set up', 'ስቱዲዮዎ ተዘጋጅቷል'),
          action: FilledButton(
            onPressed: () => context.go('/desk'),
            child: Text(context.tr('Open Studio Desk', 'የስቱዲዮ ዴስክ ክፈት')),
          ),
        );
      }
      return const _Wizard();
    });
  }
}

class _Starter {
  final ServiceTemplate template;
  bool selected = false;
  String mode = 'fixed';
  final TextEditingController price = TextEditingController();
  _Starter(this.template);
}

class _Wizard extends StatefulWidget {
  const _Wizard();
  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard> {
  int _step = 0;
  final _name = TextEditingController(text: Session.instance.profile?.name ?? '');
  final _handle = TextEditingController();
  final _area = TextEditingController();
  final _whatsapp = TextEditingController(text: Session.instance.profile?.phone ?? '');
  final _telegram = TextEditingController();
  final Set<String> _specialties = {'makeup'};
  final Set<String> _subCities = {};
  bool _atStudio = false;
  bool _home = true;
  bool _venue = false;
  bool _handleTouched = false;
  bool _showAllTemplates = false;
  bool _busy = false;
  String? _error;
  late final List<_Starter> _starters = [for (final t in kServiceTemplates) _Starter(t)];

  @override
  void initState() {
    super.initState();
    _handle.text = _suggest(_name.text);
    _name.addListener(() {
      if (!_handleTouched) _handle.text = _suggest(_name.text);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _area, _whatsapp, _telegram]) {
      c.dispose();
    }
    for (final s in _starters) {
      s.price.dispose();
    }
    super.dispose();
  }

  static String _suggest(String name) {
    final h = normalizeHandle(name.replaceAll(RegExp(r'\s+'), ''));
    return h.length > 30 ? h.substring(0, 30) : h;
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step == 0) {
      if (_name.text.trim().length < 2) {
        setState(() => _error = context.tr('Give your studio a name.', 'ለስቱዲዮዎ ስም ይስጡ።'));
        return;
      }
      final h = normalizeHandle(_handle.text);
      _handle.text = h;
      final problem = handleProblem(h);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      setState(() => _busy = true);
      try {
        final free = await StudioService.handleAvailable(h);
        if (!free) {
          setState(() => _error = context.tr('astudio.hepius.co/$h is taken. Try another.', 'astudio.hepius.co/$h ተይዟል። ሌላ ይሞክሩ።'));
          return;
        }
      } catch (_) {
        setState(() => _error = context.tr('Could not check the link. Check your connection.', 'ሊንኩን ማረጋገጥ አልተቻለም።'));
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (_step == 1) {
      if (_specialties.isEmpty) {
        setState(() => _error = context.tr('Pick at least one specialty.', 'ቢያንስ አንድ ልዩ ሙያ ይምረጡ።'));
        return;
      }
      if (!_atStudio && !_home && !_venue) {
        setState(() => _error = context.tr('Choose where you work.', 'የት እንደሚሠሩ ይምረጡ።'));
        return;
      }
      if ((_home || _venue) && _subCities.isEmpty) {
        setState(() => _error = context.tr('Pick the sub-cities you travel to.', 'የሚሄዱባቸውን ክፍለ ከተሞች ይምረጡ።'));
        return;
      }
    }
    if (_step == 2) {
      if (_whatsapp.text.trim().isEmpty && _telegram.text.trim().isEmpty) {
        setState(() => _error = context.tr('Add WhatsApp or Telegram so clients can reach you.', 'ደንበኞች እንዲያገኙዎ ዋትስአፕ ወይም ቴሌግራም ያክሉ።'));
        return;
      }
    }
    if (_step == 3) {
      for (final s in _starters.where((s) => s.selected && s.mode != 'hidden')) {
        final p = int.tryParse(s.price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (p <= 0) {
          setState(() => _error = context.tr('Add a price for ${s.template.name}, or choose "On request".',
              'ለ${s.template.name} ዋጋ ያስገቡ፣ ወይም "በጥያቄ" ይምረጡ።'));
          return;
        }
      }
      await _create();
      return;
    }
    setState(() => _step++);
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final services = <ServiceItem>[
      for (final s in _starters.where((s) => s.selected))
        ServiceItem(
          id: StudioService.newServiceId() + s.template.name.hashCode.abs().toString(),
          name: s.template.name,
          category: s.template.category,
          durationMin: s.template.minutes,
          priceMode: s.mode,
          price: s.mode == 'hidden' ? 0 : (int.tryParse(s.price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0),
        ),
    ];
    final wa = _whatsapp.text.trim();
    try {
      await StudioService.create(
        handle: normalizeHandle(_handle.text),
        name: _name.text.trim(),
        specialties: _specialties.toList(),
        subCities: _subCities.toList(),
        atStudio: _atStudio,
        homeVisits: _home,
        venueVisits: _venue,
        studioArea: _area.text.trim(),
        whatsapp: wa.isEmpty ? '' : (normalizeEthiopianPhone(wa) ?? wa),
        telegram: telegramUsername(_telegram.text),
        services: services,
      );
      if (!mounted) return;
      toast(context, context.tr('Your studio is ready. Add photos, then publish.', 'ስቱዲዮዎ ዝግጁ ነው። ፎቶዎችን ጨምረው ይክፈቱ።'));
      context.go('/desk?tab=overview');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().contains('permission')
              ? context.tr('That link was just taken. Go back and pick another.', 'ሊንኩ አሁን ተይዟል። ተመልሰው ሌላ ይምረጡ።')
              : context.tr('Could not create your studio. Try again.', 'ስቱዲዮዎን መፍጠር አልተቻለም። እንደገና ይሞክሩ።');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final titles = [
      context.tr('Name your studio', 'ስቱዲዮዎን ይሰይሙ'),
      context.tr('What you do', 'የሚሠሩት'),
      context.tr('How clients reach you', 'ደንበኞች እንዴት ያግኙዎት'),
      context.tr('Your first services', 'የመጀመሪያ አገልግሎቶችዎ'),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 28),
      children: [
        PageBody(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('STEP ${_step + 1} OF 4', 'ደረጃ ${_step + 1} ከ4'), style: labelCaps()),
              const SizedBox(height: 8),
              Text(titles[_step], style: t.textTheme.headlineLarge),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (_step + 1) / 4),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_step == 0) ..._stepName(context),
                      if (_step == 1) ..._stepWork(context),
                      if (_step == 2) ..._stepContact(context),
                      if (_step == 3) ..._stepServices(context),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                if (_step > 0)
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _step--),
                    child: Text(context.tr('Back', 'ተመለስ')),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _next,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_step == 3 ? context.tr('Create my studio', 'ስቱዲዮዬን ፍጠር') : context.tr('Next', 'ቀጥል')),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _stepName(BuildContext context) => [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.tr('Studio or artist name', 'የስቱዲዮ ወይም የባለሙያ ስም'),
            hintText: 'Hana Glam Studio',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _handle,
          onChanged: (_) => _handleTouched = true,
          decoration: InputDecoration(
            labelText: context.tr('Your link', 'ሊንክዎ'),
            prefixText: 'astudio.hepius.co/',
            helperText: context.tr('Letters, numbers, dots and dashes. You can change it later.',
                'ፊደላት፣ ቁጥሮች፣ ነጥብ እና ሰረዝ። በኋላ መቀየር ይችላሉ።'),
          ),
        ),
      ];

  List<Widget> _stepWork(BuildContext context) {
    final am = context.isAm;
    final t = Theme.of(context);
    return [
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
      const SizedBox(height: 18),
      Text(context.tr('Where you work', 'የት ይሠራሉ'), style: t.textTheme.titleSmall),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _atStudio,
        onChanged: (v) => setState(() => _atStudio = v ?? false),
        title: Text(context.tr('At my studio or salon', 'በስቱዲዮዬ ወይም በሳሎኔ')),
      ),
      if (_atStudio)
        TextField(
          controller: _area,
          decoration: InputDecoration(
            labelText: context.tr('Area and landmark', 'አካባቢ እና መለያ ምልክት'),
            hintText: context.tr('Bole, near Edna Mall', 'ቦሌ፣ ኤድና ሞል አጠገብ'),
            helperText: context.tr('Never your full home address.', 'ሙሉ የቤት አድራሻዎን በጭራሽ አይጻፉ።'),
          ),
        ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _home,
        onChanged: (v) => setState(() => _home = v ?? false),
        title: Text(context.tr('Home visits', 'ቤት ድረስ')),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _venue,
        onChanged: (v) => setState(() => _venue = v ?? false),
        title: Text(context.tr('Venues and hotels', 'የዝግጅት ቦታዎች እና ሆቴሎች')),
      ),
      const SizedBox(height: 12),
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
    ];
  }

  List<Widget> _stepContact(BuildContext context) => [
        Text(
          context.tr('These show as buttons on your page. Clients can also message you inside A Studio.',
              'እነዚህ በገጽዎ ላይ እንደ አዝራር ይታያሉ። ደንበኞች በኤ ስቱዲዮ ውስጥም መልዕክት ሊልኩልዎ ይችላሉ።'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: context.tr('WhatsApp number', 'የዋትስአፕ ቁጥር'), hintText: '0911 234 567'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telegram,
          decoration: InputDecoration(labelText: context.tr('Telegram username (optional)', 'የቴሌግራም ስም (አማራጭ)'), hintText: '@yourname'),
        ),
      ];

  List<Widget> _stepServices(BuildContext context) {
    final t = Theme.of(context);
    final visible = _starters.where((s) => _specialties.contains(s.template.category) || s.selected).toList();
    final list = (_showAllTemplates || visible.isEmpty) ? _starters : visible;
    return [
      Text(
        context.tr('Tick what you offer and set a price. You can add your own services and edit these later.',
            'የሚሰጡትን ምልክት አድርገው ዋጋ ያስቀምጡ። በኋላ የራስዎን ማከልና ማስተካከል ይችላሉ።'),
      ),
      const SizedBox(height: 10),
      for (final s in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: s.selected,
              onChanged: (v) => setState(() => s.selected = v ?? false),
              title: Text(s.template.name),
              subtitle: Text(durationLabel(s.template.minutes)),
            ),
            if (s.selected)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'fixed', label: Text(context.tr('Fixed', 'ቋሚ'))),
                      ButtonSegment(value: 'from', label: Text(context.tr('From', 'ከ'))),
                      ButtonSegment(value: 'hidden', label: Text(context.tr('On request', 'በጥያቄ'))),
                    ],
                    selected: {s.mode},
                    onSelectionChanged: (v) => setState(() => s.mode = v.first),
                  ),
                  if (s.mode != 'hidden')
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: s.price,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: context.tr('Price', 'ዋጋ'), prefixText: 'Br '),
                      ),
                    ),
                ]),
              ),
          ]),
        ),
      if (list.length < _starters.length)
        TextButton(
          onPressed: () => setState(() => _showAllTemplates = true),
          child: Text(context.tr('Show all templates', 'ሁሉንም ናሙናዎች አሳይ'), style: t.textTheme.labelLarge),
        ),
    ];
  }
}
