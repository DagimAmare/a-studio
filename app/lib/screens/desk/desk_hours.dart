import 'package:flutter/material.dart';

import '../../core/ethiopian.dart';
import '../../core/format.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/studio_service.dart';
import '../../widgets/common.dart';
import 'desk_screen.dart';

class HoursTab extends StatefulWidget {
  final Studio studio;
  const HoursTab({super.key, required this.studio});
  @override
  State<HoursTab> createState() => _HoursTabState();
}

class _HoursTabState extends State<HoursTab> {
  late final Map<String, DayHours?> _hours = {
    for (final k in kWeekdayKeys) k: widget.studio.hours[k],
  };
  late int _buffer = widget.studio.bufferMin;
  late int _notice = widget.studio.noticeHours;
  late final List<String> _blocked = [...widget.studio.blockedDates]..sort();
  bool _dirty = false;

  /// 3:00 AM to midnight in half hours: early bridal calls start before dawn.
  static final List<int> _times = [for (var m = 3 * 60; m <= 24 * 60; m += 30) m];

  void _change(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  Future<void> _addBlocked() async {
    final now = addisNow();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDate: DateTime(now.year, now.month, now.day),
      helpText: context.tr('Day off', 'የእረፍት ቀን'),
    );
    if (picked == null) return;
    final key = dateKey(picked);
    if (_blocked.contains(key)) return;
    _change(() => _blocked
      ..add(key)
      ..sort());
  }

  Future<void> _save() async {
    final today = dateKey(addisNow());
    final hours = <String, dynamic>{};
    _hours.forEach((k, v) {
      if (v != null && v.end > v.start) hours[k] = v.toMap();
    });
    await Busy.run(
      context,
      () => StudioService.update({
        'hours': hours,
        'bufferMin': _buffer,
        'noticeHours': _notice,
        // Days that have passed are dropped to keep the list short.
        'blockedDates': _blocked.where((d) => d.compareTo(today) >= 0).toList(),
      }, log: 'hours_update'),
      success: context.tr('Hours saved', 'ሰዓቱ ተቀምጧል'),
    );
    if (mounted) setState(() => _dirty = false);
  }

  String _clock(int m) => m >= 24 * 60 ? context.tr('Midnight', 'እኩለ ሌሊት') : bothClocks(m);

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    return DeskPage(
      title: context.tr('Working hours', 'የሥራ ሰዓት'),
      intro: context.tr(
          'Clients only see start times that fit inside these hours, your buffer and your existing bookings. Times are Addis Ababa time.',
          'ደንበኞች የሚያዩት በእነዚህ ሰዓቶች፣ በእረፍት ጊዜዎ እና ባሉት ቀጠሮዎች ውስጥ የሚገቡ ሰዓቶችን ብቻ ነው። ሰዓቶቹ የአዲስ አበባ ሰዓት ናቸው።'),
      trailing: FilledButton(
        onPressed: _dirty ? _save : null,
        child: Text(context.tr('Save', 'አስቀምጥ')),
      ),
      children: [
        DeskCard(
          title: context.tr('Weekly hours', 'ሳምንታዊ ሰዓት'),
          children: [
            for (var i = 0; i < kWeekdayKeys.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Row(children: [
                        Switch(
                          value: _hours[kWeekdayKeys[i]] != null,
                          onChanged: (on) => _change(() {
                            _hours[kWeekdayKeys[i]] = on ? const DayHours(7 * 60, 19 * 60) : null;
                          }),
                        ),
                        const SizedBox(width: 6),
                        Text(am ? kWeekdayAm[i] : kWeekdayEn[i], style: Theme.of(context).textTheme.titleSmall),
                      ]),
                    ),
                    if (_hours[kWeekdayKeys[i]] == null)
                      Text(context.tr('Closed', 'ዝግ'), style: Theme.of(context).textTheme.bodySmall)
                    else ...[
                      SizedBox(
                        width: 220,
                        child: SelectField<int>(
                          label: context.tr('From', 'ከ'),
                          value: _hours[kWeekdayKeys[i]]!.start,
                          items: [for (final m in _times.where((m) => m < 24 * 60)) (m, _clock(m))],
                          onChanged: (v) => _change(() {
                            final h = _hours[kWeekdayKeys[i]]!;
                            final start = v ?? h.start;
                            _hours[kWeekdayKeys[i]] = DayHours(start, h.end > start ? h.end : start + 60);
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: SelectField<int>(
                          label: context.tr('Until', 'እስከ'),
                          value: _hours[kWeekdayKeys[i]]!.end,
                          items: [
                            for (final m in _times.where((m) => m > _hours[kWeekdayKeys[i]]!.start)) (m, _clock(m))
                          ],
                          onChanged: (v) => _change(() {
                            final h = _hours[kWeekdayKeys[i]]!;
                            _hours[kWeekdayKeys[i]] = DayHours(h.start, v ?? h.end);
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        DeskCard(
          title: context.tr('Booking rules', 'የቀጠሮ ሕጎች'),
          children: [
            SelectField<int>(
              label: context.tr('Break between appointments', 'በቀጠሮዎች መካከል እረፍት'),
              value: _buffer,
              items: [
                for (final m in [0, 15, 30, 45, 60, 90, 120])
                  (m, m == 0 ? context.tr('No break', 'እረፍት የለም') : durationLabel(m))
              ],
              onChanged: (v) => _change(() => _buffer = v ?? _buffer),
            ),
            const SizedBox(height: 12),
            SelectField<int>(
              label: context.tr('Minimum notice before a booking', 'ከቀጠሮ በፊት ዝቅተኛ ማሳወቂያ'),
              value: _notice,
              items: [
                for (final h in [1, 2, 4, 6, 12, 24, 48, 72])
                  (h, context.tr('$h hours', '$h ሰዓት'))
              ],
              onChanged: (v) => _change(() => _notice = v ?? _notice),
            ),
          ],
        ),
        DeskCard(
          title: context.tr('Days off', 'የእረፍት ቀናት'),
          trailing: TextButton.icon(
            onPressed: _addBlocked,
            icon: const Icon(Icons.add),
            label: Text(context.tr('Add a day', 'ቀን ጨምር')),
          ),
          children: [
            if (_blocked.isEmpty)
              Text(context.tr('No days off planned.', 'የታቀደ የእረፍት ቀን የለም።'))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in _blocked)
                  InputChip(
                    label: Text('${dayLabelYear(parseDateKey(d))} · ${ethDayMonth(parseDateKey(d), amharic: am)}'),
                    onDeleted: () => _change(() => _blocked.remove(d)),
                  ),
              ]),
          ],
        ),
        if (_dirty)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _save, child: Text(context.tr('Save changes', 'ለውጦቹን አስቀምጥ'))),
          ),
      ],
    );
  }
}
