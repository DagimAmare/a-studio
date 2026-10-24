import 'package:flutter/material.dart';

import '../../core/ethiopian.dart';
import '../../core/format.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import 'desk_screen.dart';

class BookingsTab extends StatefulWidget {
  final Studio studio;
  final List<Booking> bookings;
  const BookingsTab({super.key, required this.studio, required this.bookings});
  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  String _view = 'action';

  @override
  Widget build(BuildContext context) {
    final today = dateKey(addisNow());
    final all = widget.bookings;
    final action = all
        .where((b) =>
            b.status == BookingStatus.requested ||
            b.status == BookingStatus.depositSubmitted ||
            b.status == BookingStatus.accepted)
        .toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100)));
    final upcoming = all
        .where((b) => b.status == BookingStatus.confirmed && b.date.compareTo(today) >= 0)
        .toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.startMin.compareTo(b.startMin);
      });
    final past = all.where((b) => !b.isOpen || (b.status == BookingStatus.confirmed && b.date.compareTo(today) < 0)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final list = _view == 'action' ? action : (_view == 'upcoming' ? upcoming : past);

    return DeskPage(
      title: context.tr('Bookings', 'ቀጠሮዎች'),
      intro: context.tr('Reply to requests within 12 hours, or they expire and the client is shown other artists.',
          'ጥያቄዎችን በ12 ሰዓት ውስጥ ይመልሱ፣ አለበለዚያ ጊዜያቸው ያልፋል።'),
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'action', label: Text('${context.tr('Needs you', 'የሚጠብቁ')} (${action.length})')),
            ButtonSegment(value: 'upcoming', label: Text('${context.tr('Upcoming', 'መጪ')} (${upcoming.length})')),
            ButtonSegment(value: 'past', label: Text(context.tr('Past', 'ያለፉ'))),
          ],
          selected: {_view},
          onSelectionChanged: (v) => setState(() => _view = v.first),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.event_available_outlined,
            title: _view == 'action'
                ? context.tr('Nothing waiting for you', 'የሚጠብቅዎት ነገር የለም')
                : context.tr('No bookings here yet', 'እዚህ ገና ቀጠሮ የለም'),
            body: _view == 'action'
                ? context.tr('Share your link to get booked.', 'ቀጠሮ ለማግኘት ሊንክዎን ያጋሩ።')
                : null,
          )
        else if (_view == 'upcoming')
          ..._grouped(context, list)
        else
          for (final b in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BookingTile(booking: b, asArtist: true),
            ),
      ],
    );
  }

  /// Upcoming bookings under one heading per day, in both calendars.
  List<Widget> _grouped(BuildContext context, List<Booking> list) {
    final out = <Widget>[];
    String? current;
    for (final b in list) {
      if (b.date != current) {
        current = b.date;
        final d = parseDateKey(b.date);
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text('${dayLabel(d)} · ${ethDayMonth(d, amharic: context.isAm)}'.toUpperCase(), style: labelCaps()),
        ));
      }
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: BookingTile(booking: b, asArtist: true),
      ));
    }
    return out;
  }
}
