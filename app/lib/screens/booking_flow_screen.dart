import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/catalog.dart';
import '../core/ethiopian.dart';
import '../core/format.dart';
import '../core/slots.dart';
import '../core/validators.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/booking_service.dart';
import '../services/db.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/common.dart';
import 'studio_screen.dart';

class BookingFlowScreen extends StatelessWidget {
  final String handle;
  const BookingFlowScreen({super.key, required this.handle});

  @override
  Widget build(BuildContext context) {
    final preselect = GoRouterState.of(context).uri.queryParameters['service'] ?? '';
    return StudioLoader(
      handle: handle,
      builder: (context, studio) => _Flow(studio: studio, preselect: preselect),
    );
  }
}

class _Flow extends StatefulWidget {
  final Studio studio;
  final String preselect;
  const _Flow({required this.studio, required this.preselect});
  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  late BookingDraft d;
  List<List<int>> _busy = const [];
  bool _loadingBusy = false;
  bool _agree = false;
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _landmark = TextEditingController();
  final _notes = TextEditingController();

  Studio get s => widget.studio;

  @override
  void initState() {
    super.initState();
    final pending = BookingDraft.pending;
    if (pending != null && pending.studio.uid == s.uid) {
      d = pending;
    } else {
      d = BookingDraft(s);
      if (!s.atStudio) d.place = s.homeVisits ? 'home' : 'venue';
      if (widget.preselect.isNotEmpty &&
          s.activeServices.any((x) => x.id == widget.preselect)) {
        d.serviceIds.add(widget.preselect);
      }
    }
    _area.text = d.area;
    _landmark.text = d.landmark;
    _notes.text = d.notes;
    _phone.text = Session.instance.profile?.phone ?? '';
    if (d.date != null) _loadBusy();
  }

  @override
  void dispose() {
    _phone.dispose();
    _area.dispose();
    _landmark.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadBusy() async {
    final date = d.date;
    if (date == null) return;
    setState(() => _loadingBusy = true);
    final busy = await BookingService.busyFor(s.uid, dateKey(date));
    if (!mounted) return;
    setState(() {
      _busy = busy;
      _loadingBusy = false;
    });
  }

  /// The earliest bookable moment, in Addis wall-clock time. Worked out in
  /// UTC so the device's own daylight saving never shifts it.
  DateTime get _earliest {
    final u = DateTime.now().toUtc().add(Duration(hours: 3 + s.noticeHours));
    return DateTime(u.year, u.month, u.day, u.hour, u.minute);
  }

  bool _dayOpen(DateTime day) {
    if (s.blockedDates.contains(dateKey(day))) return false;
    final h = s.hours[weekdayKey(day)];
    if (h == null) return false;
    final e = _earliest;
    final eDay = DateTime(e.year, e.month, e.day);
    if (day.isBefore(eDay)) return false;
    if (day == eDay && minutesOf(e) > h.end - d.durationMin) return false;
    return true;
  }

  List<int> _slotsFor(DateTime day) {
    final h = s.hours[weekdayKey(day)];
    if (h == null || d.durationMin <= 0) return const [];
    final e = _earliest;
    final eDay = DateTime(e.year, e.month, e.day);
    final earliest = day == eDay ? roundUp(minutesOf(e), 30) : 0;
    return availableStarts(
      openMin: h.start,
      closeMin: h.end,
      durationMin: d.durationMin,
      busy: _busy,
      bufferMin: s.bufferMin,
      earliestMin: earliest,
    );
  }

  Future<void> _submit() async {
    final session = Session.instance;
    d.area = _area.text;
    d.landmark = _landmark.text;
    d.notes = _notes.text;
    if (!session.signedIn) {
      BookingDraft.pending = d;
      context.go('/signin?next=${Uri.encodeComponent('/book/${s.handle}')}');
      return;
    }
    if (session.uid == s.uid) {
      toast(context, context.tr('You cannot book your own studio.', 'የራስዎን ስቱዲዮ መያዝ አይችሉም።'));
      return;
    }
    final phone = normalizeEthiopianPhone(_phone.text) ?? _phone.text.trim();
    if (phone.length < 9) {
      toast(context, context.tr('Add a phone number so the artist can reach you.', 'ባለሙያው እንዲያገኝዎ ስልክ ቁጥር ያስገቡ።'));
      return;
    }
    final id = await Busy.run(context, () async {
      if ((session.profile?.phone ?? '') != phone) {
        await Db.users
            .doc(session.uid)
            .set({'phone': phone, 'phoneVerified': false}, SetOptions(merge: true))
            .timeout(Db.timeout);
      }
      return BookingService.request(d);
    });
    if (id == null || !mounted) return;
    BookingDraft.pending = null;
    toast(context, context.tr('Request sent. ${s.name} will reply soon.', 'ጥያቄው ተልኳል። ${s.name} በቅርቡ ይመልሳሉ።'));
    context.go('/bookings/$id');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final am = context.isAm;
    final today = DateTime(addisNow().year, addisNow().month, addisNow().day);
    final days = List.generate(60, (i) => DateTime(today.year, today.month, today.day + i));
    final slots = d.date == null ? const <int>[] : _slotsFor(d.date!);

    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        PageBody(
          maxWidth: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () => context.go('/${s.handle}'),
                icon: const Icon(Icons.arrow_back),
                label: Text(s.name),
              ),
              Text(context.tr('Book ${s.name}', '${s.name}ን ይያዙ'), style: t.textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text(
                context.tr('Send a request. You pay the deposit only after the artist accepts.',
                    'ጥያቄ ይላኩ። ቅድመ ክፍያ የሚከፍሉት ባለሙያው ከተቀበለ በኋላ ብቻ ነው።'),
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              // ------------------------------------------------- 1 services
              _Step(n: 1, title: context.tr('Choose services', 'አገልግሎቶችን ይምረጡ')),
              ...s.activeServices.map((svc) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: d.serviceIds.contains(svc.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        d.serviceIds.add(svc.id);
                      } else {
                        d.serviceIds.remove(svc.id);
                      }
                      d.startMin = null;
                    }),
                    title: Text(svc.name),
                    subtitle: Text('${durationLabel(svc.durationMin)} · ${priceLabel(context, svc)}'),
                  )),
              const SizedBox(height: 6),
              Row(children: [
                Text(context.tr('People', 'ሰዎች'), style: t.textTheme.titleSmall),
                const SizedBox(width: 12),
                IconButton.outlined(
                  onPressed: d.people > 1 ? () => setState(() { d.people--; d.startMin = null; }) : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('${d.people}', style: t.textTheme.titleLarge),
                ),
                IconButton.outlined(
                  onPressed: d.people < 8 ? () => setState(() { d.people++; d.startMin = null; }) : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('For a bride and bridesmaids, add everyone here.', 'ለሙሽራ እና ሚዜዎች ሁሉንም እዚህ ይጨምሩ።'),
                    style: t.textTheme.bodySmall,
                  ),
                ),
              ]),
              // ------------------------------------------------- 2 date
              _Step(n: 2, title: context.tr('Pick a day', 'ቀን ይምረጡ')),
              if (!d.readyForTime)
                Text(context.tr('Choose a service first.', 'መጀመሪያ አገልግሎት ይምረጡ።'), style: t.textTheme.bodySmall)
              else
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (c, i) {
                      final day = days[i];
                      final open = _dayOpen(day);
                      final selected = d.date == day;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: open
                            ? () {
                                setState(() {
                                  d.date = day;
                                  d.startMin = null;
                                  _busy = const [];
                                });
                                _loadBusy();
                              }
                            : null,
                        child: Container(
                          width: 76,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? t.colorScheme.primary
                                : (open ? t.colorScheme.surface : t.colorScheme.surfaceContainerHighest),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? t.colorScheme.primary : t.dividerColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text((am ? kWeekdayAm : kWeekdayEn)[day.weekday - 1],
                                  style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontFamilyFallback: kSansFallback,
                                      fontSize: 12,
                                      color: selected ? t.colorScheme.onPrimary : t.colorScheme.onSurfaceVariant)),
                              Text('${day.day}',
                                  style: displayStyle(24,
                                      color: selected
                                          ? t.colorScheme.onPrimary
                                          : (open ? t.colorScheme.onSurface : t.colorScheme.onSurfaceVariant))),
                              Text(ethDayMonth(day, amharic: am),
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontFamilyFallback: kSansFallback,
                                      fontSize: 10.5,
                                      color: selected ? t.colorScheme.onPrimary : t.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // ------------------------------------------------- 3 time
              _Step(n: 3, title: context.tr('Pick a time', 'ሰዓት ይምረጡ')),
              if (d.date == null)
                Text(context.tr('Pick a day to see open times.', 'ክፍት ሰዓቶችን ለማየት ቀን ይምረጡ።'), style: t.textTheme.bodySmall)
              else if (_loadingBusy)
                const Loading(size: 22)
              else if (slots.isEmpty)
                Text(context.tr('No open times that day for ${durationLabel(d.durationMin)}. Try another day.',
                    'በዚያ ቀን ለ${durationLabel(d.durationMin)} ክፍት ሰዓት የለም። ሌላ ቀን ይሞክሩ።'))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in slots)
                      ChoiceChip(
                        selected: d.startMin == m,
                        onSelected: (_) => setState(() => d.startMin = m),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(clockLabel(m)),
                            Text(ethClock(m ~/ 60, m % 60),
                                style: const TextStyle(fontSize: 11, fontFamilyFallback: kSansFallback)),
                          ],
                        ),
                      ),
                  ],
                ),
              // ------------------------------------------------- 4 place
              _Step(n: 4, title: context.tr('Where', 'የት')),
              Wrap(spacing: 8, children: [
                if (s.atStudio)
                  ChoiceChip(
                    label: Text(context.tr('At the studio', 'በስቱዲዮ')),
                    selected: d.place == 'studio',
                    onSelected: (_) => setState(() => d.place = 'studio'),
                  ),
                if (s.homeVisits)
                  ChoiceChip(
                    label: Text(context.tr('At my home', 'ቤቴ')),
                    selected: d.place == 'home',
                    onSelected: (_) => setState(() => d.place = 'home'),
                  ),
                if (s.venueVisits)
                  ChoiceChip(
                    label: Text(context.tr('At a venue', 'በዝግጅት ቦታ')),
                    selected: d.place == 'venue',
                    onSelected: (_) => setState(() => d.place = 'venue'),
                  ),
              ]),
              const SizedBox(height: 12),
              if (d.place == 'studio')
                Text(
                  s.studioArea.isEmpty
                      ? context.tr('The artist shares the studio location after confirming.', 'ባለሙያው ካረጋገጡ በኋላ የስቱዲዮውን ቦታ ያጋራሉ።')
                      : '${context.tr('Studio area', 'የስቱዲዮ አካባቢ')}: ${s.studioArea}',
                  style: t.textTheme.bodyMedium,
                )
              else ...[
                SelectField<String>(
                  label: context.tr('Sub-city', 'ክፍለ ከተማ'),
                  value: d.subCity,
                  items: [for (final c in kSubCities) (c.id, c.label(am))],
                  onChanged: (v) => setState(() => d.subCity = v ?? ''),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _area,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: context.tr('Area or neighbourhood (e.g. Gerji)', 'ሰፈር (ለምሳሌ ገርጂ)')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _landmark,
                  maxLength: 280,
                  onChanged: (_) => setState(() => d.landmark = _landmark.text),
                  decoration: InputDecoration(
                    labelText: context.tr('Landmark and directions (required)', 'መለያ ምልክት እና አቅጣጫ (ግዴታ)'),
                    hintText: context.tr('e.g. behind Unity Park gate, blue gate, 3rd floor', 'ለምሳሌ ከ... ጀርባ፣ ሰማያዊ በር'),
                  ),
                ),
                if (s.travelFee > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${context.tr('Travel fee', 'የትራንስፖርት ክፍያ')}: ${birr(s.travelFee)}',
                        style: t.textTheme.bodySmall),
                  ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                maxLines: 3,
                maxLength: 900,
                decoration: InputDecoration(
                  labelText: context.tr('Notes for the artist (optional)', 'ለባለሙያው ማስታወሻ (አማራጭ)'),
                  hintText: context.tr('Skin type, the look you want, outfit colours...', 'የቆዳ አይነት፣ የሚፈልጉት ገጽታ፣ የልብስ ቀለም...'),
                ),
              ),
              // ------------------------------------------------- 5 review
              _Step(n: 5, title: context.tr('Review and send', 'ይገምግሙ እና ይላኩ')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final svc in d.selected)
                        _Line('${svc.name}${d.people > 1 ? ' × ${d.people}' : ''}',
                            svc.priceHidden ? context.tr('on request', 'በጥያቄ') : '${svc.priceFrom ? context.tr('from ', 'ከ ') : ''}${birr(svc.price * d.people)}'),
                      if (d.travelFee > 0) _Line(context.tr('Travel fee', 'የትራንስፖርት ክፍያ'), birr(d.travelFee)),
                      const Divider(height: 22),
                      _Line(context.tr('Total', 'ጠቅላላ'),
                          '${d.totalIsFrom ? context.tr('from ', 'ከ ') : ''}${birr(d.total)}${d.hasHiddenPrice ? context.tr(' + priced items', ' + ዋጋ የሚነገሩ') : ''}',
                          bold: true),
                      _Line(
                          context.tr('Deposit after acceptance (${s.depositPercent}%)', 'ከተቀበሉ በኋላ ቅድመ ክፍያ (${s.depositPercent}%)'),
                          birr(d.depositAmount)),
                      if (d.date != null && d.startMin != null) ...[
                        const SizedBox(height: 10),
                        Text('${dayLabelYear(d.date!)} · ${ethFull(d.date!, amharic: am)}', style: t.textTheme.bodyMedium),
                        Text('${bothClocks(d.startMin!)} · ${durationLabel(d.durationMin)}', style: t.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 10),
                      Text(am ? policyById(s.cancellationPolicy).detailAm : policyById(s.cancellationPolicy).detailEn,
                          style: t.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (Session.instance.signedIn)
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('Your phone number', 'የስልክ ቁጥርዎ'),
                    hintText: '09XX XXX XXX',
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _agree,
                onChanged: (v) => setState(() => _agree = v ?? false),
                title: Text(
                  context.tr(
                      'I understand A Studio connects me with an independent artist. The service is provided by the artist, under the Terms of Use.',
                      'ኤ ስቱዲዮ ከገለልተኛ ባለሙያ ጋር እንደሚያገናኘኝ ተረድቻለሁ። አገልግሎቱ የሚሰጠው በባለሙያው ነው።'),
                  style: t.textTheme.bodySmall,
                ),
                secondary: TextButton(
                  onPressed: () => openExternal(AppConfig.termsPath),
                  child: Text(context.tr('Terms', 'ውል')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: d.readyForPlace && d.placeComplete && _agree ? _submit : null,
                  child: Text(Session.instance.signedIn
                      ? context.tr('Send booking request', 'የቀጠሮ ጥያቄ ላክ')
                      : context.tr('Sign in to send request', 'ጥያቄ ለመላክ ይግቡ')),
                ),
              ),
              if (!(d.readyForPlace && d.placeComplete))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.tr('Choose a service, day, time and place to continue.', 'ለመቀጠል አገልግሎት፣ ቀን፣ ሰዓት እና ቦታ ይምረጡ።'),
                    style: t.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  const _Step({required this.n, required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.espresso, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(fontFamily: 'DMSans', color: AppColors.milk, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ]),
      );
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Line(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) {
    final style = bold ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ]),
    );
  }
}
