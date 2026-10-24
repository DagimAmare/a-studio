import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/booking_service.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});
  @override
  Widget build(BuildContext context) => SignedInGate(builder: (_) => const _MyBookings());
}

class _MyBookings extends StatefulWidget {
  const _MyBookings();
  @override
  State<_MyBookings> createState() => _MyBookingsState();
}

class _MyBookingsState extends State<_MyBookings> {
  late final Stream<List<Booking>> _stream = BookingService.asClient();
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Booking>[];
        final list = all.where((b) => _past ? !b.isOpen : b.isOpen).toList();
        if (!_past) list.sort((a, b) => (a.startAt ?? DateTime(2100)).compareTo(b.startAt ?? DateTime(2100)));
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageBody(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(context.tr('My bookings', 'ቀጠሮዎቼ')),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(context.tr('Upcoming', 'መጪ'))),
                      ButtonSegment(value: true, label: Text(context.tr('Past', 'ያለፉ'))),
                    ],
                    selected: {_past},
                    onSelectionChanged: (v) => setState(() => _past = v.first),
                  ),
                  const SizedBox(height: 16),
                  if (snap.connectionState == ConnectionState.waiting && all.isEmpty)
                    const Loading()
                  else if (list.isEmpty)
                    EmptyState(
                      icon: Icons.event_outlined,
                      title: _past
                          ? context.tr('No past bookings', 'ያለፉ ቀጠሮዎች የሉም')
                          : context.tr('Nothing booked yet', 'እስካሁን ምንም አልተያዘም'),
                      action: FilledButton(
                        onPressed: () => context.go('/explore'),
                        child: Text(context.tr('Find an artist', 'ባለሙያ ያግኙ')),
                      ),
                    )
                  else
                    ...list.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BookingTile(booking: b, asArtist: false),
                        )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
