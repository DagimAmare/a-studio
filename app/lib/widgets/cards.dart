import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/catalog.dart';
import '../core/format.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'common.dart';

class ArtistCard extends StatelessWidget {
  final Studio studio;
  final String? coverOverride;
  final double width;
  const ArtistCard({super.key, required this.studio, this.coverOverride, this.width = 280});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final am = context.isAm;
    final cover = coverOverride ?? (studio.coverType == 'image' ? studio.coverUrl : '');
    final from = studio.fromPrice;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/${studio.handle}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover.isEmpty
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.petal, AppColors.latte],
                              ),
                            ),
                          )
                        : NetImage(cover),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Wrap(spacing: 6, children: [
                        if (studio.isVerified)
                          Pill(context.tr('Verified', 'የተረጋገጠ'),
                              icon: Icons.verified_outlined,
                              background: AppColors.milk),
                        if (!studio.isVerified && studio.isNew)
                          Pill(context.tr('New', 'አዲስ'), background: AppColors.milk),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Avatar(url: studio.avatarUrl, name: studio.name, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(studio.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(21, color: t.colorScheme.onSurface)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      [
                        ...studio.subCities.take(2).map((c) => optionById(kSubCities, c).label(am)),
                        ...studio.specialties.take(2).map((c) => optionById(kServiceCategories, c).label(am)),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (studio.ratingCount > 0) ...[
                        const Icon(Icons.star_rounded, size: 16, color: AppColors.champagne),
                        const SizedBox(width: 3),
                        Text('${studio.ratingAvg.toStringAsFixed(1)} (${studio.ratingCount})',
                            style: t.textTheme.labelMedium),
                        const SizedBox(width: 10),
                      ],
                      if (from != null)
                        Text('${context.tr('from', 'ከ')} ${birr(from)}',
                            style: t.textTheme.labelMedium),
                      const Spacer(),
                      if (studio.homeVisits)
                        Tooltip(
                          message: context.tr('Home visits', 'ቤት ድረስ'),
                          child: Icon(Icons.home_outlined, size: 18, color: t.colorScheme.onSurfaceVariant),
                        ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LookTile extends StatelessWidget {
  final Look look;
  final VoidCallback? onTap;
  final bool showArtist;
  const LookTile({super.key, required this.look, this.onTap, this.showArtist = true});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: AppColors.oat,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              look.isVideo && look.thumbUrl.isEmpty
                  ? Container(
                      color: AppColors.espresso,
                      alignment: Alignment.center,
                      child: const Icon(Icons.play_circle_outline, color: AppColors.milk, size: 40),
                    )
                  : NetImage(look.preview),
              if (look.isVideo)
                const Positioned(
                  right: 10,
                  top: 10,
                  child: Icon(Icons.videocam_outlined, color: AppColors.milk, size: 20),
                ),
              if (showArtist && look.studioName.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.espresso.withValues(alpha: 0.65)],
                      ),
                    ),
                    child: Text(look.studioName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'DMSans',
                            color: AppColors.milk,
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListingCard extends StatelessWidget {
  final Listing listing;
  final double width;
  const ListingCard({super.key, required this.listing, this.width = 220});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final am = context.isAm;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/shop/${listing.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(listing.cover),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Pill(
                        listing.official
                            ? 'A Studio'
                            : (listing.isPreLoved
                                ? context.tr('Pre-loved', 'ያገለገለ')
                                : context.tr('New', 'አዲስ')),
                        background: listing.official ? AppColors.espresso : AppColors.milk,
                        foreground: listing.official ? AppColors.milk : AppColors.cocoa,
                      ),
                    ),
                    if (listing.status == 'sold')
                      Container(
                        color: AppColors.espresso.withValues(alpha: 0.55),
                        alignment: Alignment.center,
                        child: Text(context.tr('SOLD', 'ተሽጧል'), style: labelCaps(color: AppColors.milk, size: 16)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(birr(listing.price), style: t.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        optionById(kConditions, listing.condition).label(am),
                        if (listing.subCity.isNotEmpty) optionById(kSubCities, listing.subCity).label(am),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color statusColor(String status) {
  switch (status) {
    case BookingStatus.confirmed:
    case BookingStatus.completed:
      return AppColors.sage;
    case BookingStatus.requested:
    case BookingStatus.accepted:
    case BookingStatus.depositSubmitted:
      return AppColors.honey;
    default:
      return AppColors.taupe;
  }
}

class BookingTile extends StatelessWidget {
  final Booking booking;
  final bool asArtist;
  const BookingTile({super.key, required this.booking, required this.asArtist});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final b = booking;
    final date = b.date.isEmpty ? null : parseDateKey(b.date);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go('/bookings/${b.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.oat,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Text(date == null ? '' : '${date.day}', style: displayStyle(24, color: AppColors.espresso)),
                  Text(date == null ? '' : dayLabel(date).split(' ').last.toUpperCase(),
                      style: labelCaps(size: 10, spacing: 1.2)),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asArtist ? b.clientName : b.artistName,
                        style: t.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${b.servicesLabel} · ${clockLabel(b.startMin)}',
                        style: t.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: statusColor(b.status), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(BookingStatus.label(b.status, context.isAm),
                            style: t.textTheme.labelMedium, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ),
              ),
              Text(b.ref, style: labelCaps(size: 11, spacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}
