import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'activity.dart';
import 'db.dart';
import 'notification_service.dart';
import 'session.dart';

class ReviewService {
  ReviewService._();

  static Stream<List<Review>> forStudio(String uid) => Db.reviews
      .where('studioUid', isEqualTo: uid)
      .limit(200)
      .snapshots()
      .map((q) {
        final list = q.docs.map(Review.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2100))
            .compareTo(a.createdAt ?? DateTime(2100)));
        return list;
      });

  /// One review per completed booking; the review id is the booking id.
  static Future<void> submit(Booking b,
      {required int rating,
      required int skill,
      required int punctuality,
      required int hygiene,
      required int value,
      required String text}) async {
    final s = Session.instance;
    final batch = Db.fs.batch();
    batch.set(Db.reviews.doc(b.id), {
      'studioUid': b.artistUid,
      'clientUid': s.uid,
      'clientName': s.profile?.firstName ?? s.displayName,
      'rating': rating,
      'skill': skill,
      'punctuality': punctuality,
      'hygiene': hygiene,
      'value': value,
      'text': text.trim(),
      'reply': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(Db.bookings.doc(b.id), {
      'reviewed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(Db.timeout);
    NotificationService.notify(
      toUid: b.artistUid,
      type: 'review',
      title: 'New $rating-star review',
      body: text.trim().isEmpty ? 'From ${s.displayName}' : text.trim(),
      link: '/desk?tab=reviews',
      refId: b.id,
    );
    Activity.log('review_create', targetType: 'review', targetId: b.id, summary: '$rating stars');
  }

  static Future<void> reply(Review r, String text) async {
    await Db.reviews.doc(r.id).update({
      'reply': text.trim(),
      'replyAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout);
    Activity.log('review_reply', targetType: 'review', targetId: r.id);
  }

  /// Average from the reviews themselves, so a studio page is right even
  /// before the aggregate Cloud Function has run.
  static (double, int) summarize(List<Review> reviews) {
    if (reviews.isEmpty) return (0, 0);
    final sum = reviews.fold<int>(0, (a, r) => a + r.rating);
    return (sum / reviews.length, reviews.length);
  }
}
