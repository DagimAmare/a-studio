import 'package:cloud_firestore/cloud_firestore.dart';

/// Typed shortcuts to every collection. One place to see the data shape.
class Db {
  Db._();
  static FirebaseFirestore get fs => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users => fs.collection('users');
  static CollectionReference<Map<String, dynamic>> get admins => fs.collection('admins');
  static CollectionReference<Map<String, dynamic>> get handles => fs.collection('handles');
  static CollectionReference<Map<String, dynamic>> get studios => fs.collection('studios');
  static CollectionReference<Map<String, dynamic>> get looks => fs.collection('looks');
  static CollectionReference<Map<String, dynamic>> get bookings => fs.collection('bookings');
  static CollectionReference<Map<String, dynamic>> get busy => fs.collection('busy');
  static CollectionReference<Map<String, dynamic>> get reviews => fs.collection('reviews');
  static CollectionReference<Map<String, dynamic>> get chats => fs.collection('chats');
  static CollectionReference<Map<String, dynamic>> get notifications =>
      fs.collection('notifications');
  static CollectionReference<Map<String, dynamic>> get listings => fs.collection('listings');
  static CollectionReference<Map<String, dynamic>> get activity => fs.collection('activity');
  static CollectionReference<Map<String, dynamic>> get reports => fs.collection('reports');

  static DocumentReference<Map<String, dynamic>> studioPrivate(String uid) =>
      studios.doc(uid).collection('private').doc('payment');

  static const Duration timeout = Duration(seconds: 20);
}
