import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'activity.dart';
import 'db.dart';
import 'media_service.dart';

class ListingService {
  ListingService._();

  static List<Listing> _sorted(QuerySnapshot<Map<String, dynamic>> q) {
    final list = q.docs.map(Listing.fromDoc).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(2100))
        .compareTo(a.createdAt ?? DateTime(2100)));
    return list;
  }

  static Stream<List<Listing>> active() => Db.listings
      .where('status', isEqualTo: 'active')
      .limit(400)
      .snapshots()
      .map(_sorted);

  static Stream<List<Listing>> bySeller(String uid) => Db.listings
      .where('sellerUid', isEqualTo: uid)
      .limit(200)
      .snapshots()
      .map(_sorted);

  /// A seller's items for sale, readable by anyone (studio pages). Two
  /// equality filters are served by Firestore's index merging, no
  /// composite index needed.
  static Stream<List<Listing>> activeBySeller(String uid) => Db.listings
      .where('sellerUid', isEqualTo: uid)
      .where('status', isEqualTo: 'active')
      .limit(60)
      .snapshots()
      .map(_sorted);

  static Stream<Listing?> watch(String id) => Db.listings
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Listing.fromDoc(d) : null);

  static Future<String> create(Map<String, dynamic> data) async {
    final ref = await Db.listings.add({
      ...data,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout);
    Activity.log('listing_create', targetType: 'listing', targetId: ref.id, summary: '${data['title']}');
    return ref.id;
  }

  static Future<void> update(String id, Map<String, dynamic> data) async {
    await Db.listings.doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(Db.timeout);
    Activity.log('listing_update', targetType: 'listing', targetId: id, summary: data.keys.join(', '));
  }

  static Future<void> setStatus(String id, String status) => update(id, {'status': status});

  static Future<void> delete(Listing l) async {
    await Db.listings.doc(l.id).delete().timeout(Db.timeout);
    for (final p in l.photos) {
      MediaService.delete(p);
    }
    Activity.log('listing_delete', targetType: 'listing', targetId: l.id, summary: l.title);
  }
}
