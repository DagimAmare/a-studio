import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/review_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'desk_screen.dart';

class ReviewsTab extends StatefulWidget {
  final Studio studio;
  const ReviewsTab({super.key, required this.studio});
  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  late final Stream<List<Review>> _reviews = ReviewService.forStudio(widget.studio.uid);

  Future<void> _reply(Review r) async {
    final text = await textPrompt(context,
        title: context.tr('Reply to ${r.clientName}', 'ለ${r.clientName} መልስ'),
        hint: context.tr('Thank her, or answer a concern. Your reply is public.', 'ያመስግኑ ወይም ስጋቷን ይመልሱ። መልስዎ ለሁሉም ይታያል።'),
        initial: r.reply,
        maxLines: 4,
        required: true,
        confirm: context.tr('Post reply', 'መልሱን ለጥፍ'));
    if (text == null || !mounted) return;
    await Busy.run(context, () => ReviewService.reply(r, text), success: context.tr('Reply posted', 'መልሱ ተለጥፏል'));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return StreamBuilder<List<Review>>(
      stream: _reviews,
      builder: (context, snap) {
        final reviews = snap.data ?? const <Review>[];
        final (avg, count) = ReviewService.summarize(reviews);
        double sub(int Function(Review) f) =>
            reviews.isEmpty ? 0 : reviews.fold<int>(0, (a, r) => a + f(r)) / reviews.length;
        return DeskPage(
          title: context.tr('Reviews', 'ግምገማዎች'),
          intro: context.tr('Only clients with a completed booking can review you. You can reply once to each review; reviews cannot be hidden.',
              'ቀጠሮ የጨረሱ ደንበኞች ብቻ ይገመግማሉ። ለእያንዳንዱ ግምገማ አንድ ጊዜ መመለስ ይችላሉ፤ ግምገማዎች አይደበቁም።'),
          children: [
            if (count > 0)
              DeskCard(children: [
                Row(children: [
                  Text(avg.toStringAsFixed(1), style: displayStyle(48, color: t.colorScheme.onSurface)),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    RatingStars(avg, size: 20),
                    Text(context.tr('$count reviews', '$count ግምገማዎች')),
                  ]),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 18, runSpacing: 6, children: [
                  Text('${context.tr('Skill', 'ክህሎት')} ${sub((r) => r.skill).toStringAsFixed(1)}'),
                  Text('${context.tr('Punctuality', 'ሰዓት አክባሪነት')} ${sub((r) => r.punctuality).toStringAsFixed(1)}'),
                  Text('${context.tr('Hygiene', 'ንጽሕና')} ${sub((r) => r.hygiene).toStringAsFixed(1)}'),
                  Text('${context.tr('Value', 'ዋጋ')} ${sub((r) => r.value).toStringAsFixed(1)}'),
                ]),
              ]),
            if (reviews.isEmpty && snap.connectionState != ConnectionState.waiting)
              EmptyState(
                icon: Icons.star_outline,
                title: context.tr('No reviews yet', 'ገና ግምገማ የለም'),
                body: context.tr('After you mark a booking completed, the client is asked to review you.',
                    'ቀጠሮን እንደተጠናቀቀ ሲያደርጉ ደንበኛው እንዲገመግምዎ ይጠየቃል።'),
              ),
            for (final r in reviews)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      RatingStars(r.rating.toDouble()),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.clientName, style: t.textTheme.titleSmall)),
                      Text(timeAgo(r.createdAt), style: t.textTheme.bodySmall),
                    ]),
                    if (r.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(r.text),
                    ],
                    const SizedBox(height: 10),
                    if (r.reply.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('${context.tr('Your reply', 'መልስዎ')}: ${r.reply}'),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _reply(r),
                        icon: const Icon(Icons.reply, size: 18),
                        label: Text(context.tr('Reply', 'መልስ')),
                      ),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}
