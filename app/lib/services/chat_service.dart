import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'activity.dart';
import 'db.dart';
import 'notification_service.dart';
import 'session.dart';

/// One conversation per pair of people (sorted uids), as in Alfam.
/// Booking and listing context arrives as cards inside the thread.
class ChatService {
  ChatService._();

  static String chatIdWith(String otherUid) {
    final ids = [Session.instance.uid, otherUid]..sort();
    return ids.join('_');
  }

  static Stream<List<Chat>> myChats() {
    final uid = Session.instance.uid;
    return Db.chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((q) {
      final list = q.docs.map(Chat.fromDoc).toList();
      list.sort((a, b) => (b.updatedAt ?? DateTime(2100))
          .compareTo(a.updatedAt ?? DateTime(2100)));
      return list;
    });
  }

  static Stream<Chat?> watch(String chatId) => Db.chats
      .doc(chatId)
      .snapshots()
      .map((d) => d.exists ? Chat.fromDoc(d) : null);

  static Stream<List<ChatMessage>> messages(String chatId) => Db.chats
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(150)
      .snapshots()
      .map((q) => q.docs.map(ChatMessage.fromDoc).toList());

  static String preview(String kind, String text, String refTitle) {
    switch (kind) {
      case 'image':
        return 'Photo';
      case 'booking':
        return 'Booking: $refTitle';
      case 'listing':
        return 'About: $refTitle';
    }
    return text;
  }

  /// Sends a message, creating the chat on first contact.
  static Future<void> send({
    required String otherUid,
    required String otherName,
    String otherPhoto = '',
    String text = '',
    String kind = 'text',
    String imageUrl = '',
    String refId = '',
    String refTitle = '',
    String refSubtitle = '',
    String refLink = '',
  }) async {
    final s = Session.instance;
    final me = s.uid;
    final id = chatIdWith(otherUid);
    final chatRef = Db.chats.doc(id);
    final line = preview(kind, text, refTitle);
    final batch = Db.fs.batch();
    batch.set(
        chatRef,
        {
          'participants': [me, otherUid]..sort(),
          'names': {me: s.displayName, otherUid: otherName},
          'photos': {
            me: s.profile?.photoUrl ?? s.studio?.avatarUrl ?? '',
            otherUid: otherPhoto,
          },
          'lastMessage': line.length > 160 ? line.substring(0, 160) : line,
          'lastSenderUid': me,
          'updatedAt': FieldValue.serverTimestamp(),
          'unread': {otherUid: FieldValue.increment(1), me: 0},
        },
        SetOptions(merge: true));
    batch.set(chatRef.collection('messages').doc(), {
      'senderUid': me,
      'text': text,
      'kind': kind,
      if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (refId.isNotEmpty) 'refId': refId,
      if (refTitle.isNotEmpty) 'refTitle': refTitle,
      if (refSubtitle.isNotEmpty) 'refSubtitle': refSubtitle,
      if (refLink.isNotEmpty) 'refLink': refLink,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(Db.timeout);
    // One notification per conversation, refreshed with the latest line.
    NotificationService.notify(
      toUid: otherUid,
      type: 'message',
      title: s.displayName,
      body: line,
      link: '/inbox/$id',
      refId: id,
      docId: 'chat_${id}_$otherUid',
    );
    Activity.log('message_send', targetType: 'chat', targetId: id);
  }

  static void markSeen(String chatId) {
    final me = Session.instance.uid;
    Db.chats
        .doc(chatId)
        .update({'unread.$me': 0})
        .timeout(Db.timeout)
        .catchError((_) {});
    NotificationService.markRead('chat_${chatId}_$me');
  }
}
