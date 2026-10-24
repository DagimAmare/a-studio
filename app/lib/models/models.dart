import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? tsToDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _s(Object? v, [String fallback = '']) => v is String ? v : fallback;
int _i(Object? v, [int fallback = 0]) =>
    v is int ? v : (v is num ? v.toInt() : fallback);
double _d(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;
bool _b(Object? v, [bool fallback = false]) => v is bool ? v : fallback;
List<String> _ls(Object? v) =>
    v is List ? v.whereType<String>().toList() : <String>[];
Map<String, dynamic> _m(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

// ---------------------------------------------------------------- users

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  final String role; // client | artist
  final String lang;
  final String birthday; // MM-DD or ''
  final bool emailNotifs;
  final bool marketing;
  final String status; // active | suspended
  final bool emailVerified;
  final bool phoneVerified;
  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.role,
    required this.lang,
    required this.birthday,
    required this.emailNotifs,
    required this.marketing,
    required this.status,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.createdAt,
  });

  bool get isArtist => role == 'artist';
  bool get suspended => status == 'suspended';
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) =>
      UserProfile(
        uid: uid,
        name: _s(m['name']),
        email: _s(m['email']),
        phone: _s(m['phone']),
        photoUrl: _s(m['photoUrl']),
        role: _s(m['role'], 'client'),
        lang: _s(m['lang'], 'en'),
        birthday: _s(m['birthday']),
        emailNotifs: _b(_m(m['prefs'])['email'], true),
        marketing: _b(_m(m['prefs'])['marketing'], true),
        status: _s(m['status'], 'active'),
        emailVerified: _b(m['emailVerified']),
        phoneVerified: _b(m['phoneVerified']),
        createdAt: tsToDate(m['createdAt']),
      );
}

// ---------------------------------------------------------------- studios

class ServiceItem {
  final String id;
  final String name;
  final String category;
  final int durationMin;
  final String priceMode; // fixed | from | hidden
  final int price;
  final String description;
  final bool active;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMin,
    required this.priceMode,
    required this.price,
    this.description = '',
    this.active = true,
  });

  bool get priceHidden => priceMode == 'hidden';
  bool get priceFrom => priceMode == 'from';

  factory ServiceItem.fromMap(Map<String, dynamic> m) => ServiceItem(
        id: _s(m['id']),
        name: _s(m['name']),
        category: _s(m['category'], 'makeup'),
        durationMin: _i(m['durationMin'], 60),
        priceMode: _s(m['priceMode'], 'fixed'),
        price: _i(m['price']),
        description: _s(m['description']),
        active: _b(m['active'], true),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'durationMin': durationMin,
        'priceMode': priceMode,
        'price': price,
        'description': description,
        'active': active,
      };

  ServiceItem copyWith({
    String? name,
    String? category,
    int? durationMin,
    String? priceMode,
    int? price,
    String? description,
    bool? active,
  }) =>
      ServiceItem(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        durationMin: durationMin ?? this.durationMin,
        priceMode: priceMode ?? this.priceMode,
        price: price ?? this.price,
        description: description ?? this.description,
        active: active ?? this.active,
      );
}

class DayHours {
  final int start; // minutes after midnight
  final int end;
  const DayHours(this.start, this.end);
  Map<String, dynamic> toMap() => {'start': start, 'end': end};
}

class StudioDecor {
  final String theme;
  final String accent;
  final String font;
  const StudioDecor({this.theme = 'milk', this.accent = 'rouge', this.font = 'bodoni'});
  factory StudioDecor.fromMap(Map<String, dynamic> m) => StudioDecor(
        theme: _s(m['theme'], 'milk'),
        accent: _s(m['accent'], 'rouge'),
        font: _s(m['font'], 'bodoni'),
      );
  Map<String, dynamic> toMap() => {'theme': theme, 'accent': accent, 'font': font};
}

class Studio {
  final String uid;
  final String handle;
  final String name;
  final String tagline;
  final String bio;
  final List<String> specialties;
  final List<String> subCities;
  final bool atStudio;
  final bool homeVisits;
  final bool venueVisits;
  final String studioArea;
  final int travelFee;
  final String whatsapp;
  final String telegram;
  final String avatarUrl;
  final String coverUrl;
  final String coverType;
  final String status; // draft | live | suspended
  final String verification; // none | pending | verified | rejected
  final String verificationNote;
  final List<String> badges;
  final bool featured;
  final StudioDecor decor;
  final List<ServiceItem> services;
  final Map<String, DayHours> hours;
  final int bufferMin;
  final int noticeHours;
  final List<String> blockedDates;
  final int depositPercent;
  final String cancellationPolicy;
  final double ratingAvg;
  final int ratingCount;
  final bool emailVerified;
  final bool phoneVerified;
  final DateTime? createdAt;
  final DateTime? publishedAt;

  const Studio({
    required this.uid,
    required this.handle,
    required this.name,
    this.tagline = '',
    this.bio = '',
    this.specialties = const [],
    this.subCities = const [],
    this.atStudio = true,
    this.homeVisits = true,
    this.venueVisits = false,
    this.studioArea = '',
    this.travelFee = 0,
    this.whatsapp = '',
    this.telegram = '',
    this.avatarUrl = '',
    this.coverUrl = '',
    this.coverType = 'image',
    this.status = 'draft',
    this.verification = 'none',
    this.verificationNote = '',
    this.badges = const [],
    this.featured = false,
    this.decor = const StudioDecor(),
    this.services = const [],
    this.hours = const {},
    this.bufferMin = 30,
    this.noticeHours = 12,
    this.blockedDates = const [],
    this.depositPercent = 30,
    this.cancellationPolicy = 'standard',
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.createdAt,
    this.publishedAt,
  });

  bool get isLive => status == 'live';
  bool get isVerified => verification == 'verified';
  bool get isNew =>
      publishedAt == null ||
      DateTime.now().difference(publishedAt!).inDays < 30;
  List<ServiceItem> get activeServices =>
      services.where((s) => s.active).toList();

  /// Lowest visible price, for "from Br 1,500" on cards. Null if none shown.
  int? get fromPrice {
    final prices = activeServices
        .where((s) => !s.priceHidden && s.price > 0)
        .map((s) => s.price)
        .toList();
    if (prices.isEmpty) return null;
    prices.sort();
    return prices.first;
  }

  factory Studio.fromMap(String uid, Map<String, dynamic> m) {
    final hoursRaw = _m(m['hours']);
    final hours = <String, DayHours>{};
    hoursRaw.forEach((k, v) {
      final h = _m(v);
      if (h.containsKey('start') && h.containsKey('end')) {
        hours[k] = DayHours(_i(h['start']), _i(h['end']));
      }
    });
    final services = (m['services'] is List ? m['services'] as List : const [])
        .whereType<Map>()
        .map((e) => ServiceItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final modes = _m(m['workModes']);
    return Studio(
      uid: uid,
      handle: _s(m['handle']),
      name: _s(m['name']),
      tagline: _s(m['tagline']),
      bio: _s(m['bio']),
      specialties: _ls(m['specialties']),
      subCities: _ls(m['subCities']),
      atStudio: _b(modes['studio'], true),
      homeVisits: _b(modes['home'], true),
      venueVisits: _b(modes['venue'], false),
      studioArea: _s(m['studioArea']),
      travelFee: _i(m['travelFee']),
      whatsapp: _s(m['whatsapp']),
      telegram: _s(m['telegram']),
      avatarUrl: _s(m['avatarUrl']),
      coverUrl: _s(m['coverUrl']),
      coverType: _s(m['coverType'], 'image'),
      status: _s(m['status'], 'draft'),
      verification: _s(m['verification'], 'none'),
      verificationNote: _s(m['verificationNote']),
      badges: _ls(m['badges']),
      featured: _b(m['featured']),
      decor: StudioDecor.fromMap(_m(m['decor'])),
      services: services,
      hours: hours,
      bufferMin: _i(m['bufferMin'], 30),
      noticeHours: _i(m['noticeHours'], 12),
      blockedDates: _ls(m['blockedDates']),
      depositPercent: _i(m['depositPercent'], 30),
      cancellationPolicy: _s(m['cancellationPolicy'], 'standard'),
      ratingAvg: _d(m['ratingAvg']),
      ratingCount: _i(m['ratingCount']),
      emailVerified: _b(m['emailVerified']),
      phoneVerified: _b(m['phoneVerified']),
      createdAt: tsToDate(m['createdAt']),
      publishedAt: tsToDate(m['publishedAt']),
    );
  }
}

class PaymentDetails {
  final String telebirr;
  final String cbeAccount;
  final String cbeName;
  final String note;
  const PaymentDetails({
    this.telebirr = '',
    this.cbeAccount = '',
    this.cbeName = '',
    this.note = '',
  });
  bool get isEmpty =>
      telebirr.isEmpty && cbeAccount.isEmpty && note.isEmpty;
  factory PaymentDetails.fromMap(Map<String, dynamic> m) => PaymentDetails(
        telebirr: _s(m['telebirr']),
        cbeAccount: _s(m['cbeAccount']),
        cbeName: _s(m['cbeName']),
        note: _s(m['note']),
      );
  Map<String, dynamic> toMap() => {
        'telebirr': telebirr,
        'cbeAccount': cbeAccount,
        'cbeName': cbeName,
        'note': note,
      };
}

class Look {
  final String id;
  final String studioUid;
  final String studioHandle;
  final String studioName;
  final String url;
  final String thumbUrl;
  final String type; // image | video
  final String caption;
  final String occasion;
  final DateTime? createdAt;

  const Look({
    required this.id,
    required this.studioUid,
    required this.studioHandle,
    required this.studioName,
    required this.url,
    required this.thumbUrl,
    required this.type,
    this.caption = '',
    this.occasion = '',
    this.createdAt,
  });

  bool get isVideo => type == 'video';
  String get preview => thumbUrl.isNotEmpty ? thumbUrl : url;

  factory Look.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return Look(
      id: d.id,
      studioUid: _s(m['studioUid']),
      studioHandle: _s(m['studioHandle']),
      studioName: _s(m['studioName']),
      url: _s(m['url']),
      thumbUrl: _s(m['thumbUrl']),
      type: _s(m['type'], 'image'),
      caption: _s(m['caption']),
      occasion: _s(m['occasion']),
      createdAt: tsToDate(m['createdAt']),
    );
  }
}

// ---------------------------------------------------------------- bookings

class BookingItem {
  final String serviceId;
  final String name;
  final int durationMin;
  final String priceMode;
  final int price;
  const BookingItem(this.serviceId, this.name, this.durationMin, this.priceMode, this.price);
  factory BookingItem.fromMap(Map<String, dynamic> m) => BookingItem(
        _s(m['serviceId']),
        _s(m['name']),
        _i(m['durationMin']),
        _s(m['priceMode'], 'fixed'),
        _i(m['price']),
      );
  Map<String, dynamic> toMap() => {
        'serviceId': serviceId,
        'name': name,
        'durationMin': durationMin,
        'priceMode': priceMode,
        'price': price,
      };
}

class BookingStatus {
  BookingStatus._();
  static const requested = 'requested';
  static const accepted = 'accepted';
  static const depositSubmitted = 'deposit_submitted';
  static const confirmed = 'confirmed';
  static const completed = 'completed';
  static const declined = 'declined';
  static const cancelledClient = 'cancelled_client';
  static const cancelledArtist = 'cancelled_artist';
  static const noShow = 'no_show';
  static const expired = 'expired';

  static const open = {requested, accepted, depositSubmitted, confirmed};
  static const closed = {completed, declined, cancelledClient, cancelledArtist, noShow, expired};

  /// Mirrors the Firestore rules exactly.
  static bool artistMay(String from, String to) {
    if (from == to) return true;
    switch (from) {
      case requested:
        return to == accepted || to == confirmed || to == declined;
      case accepted:
        return to == confirmed || to == cancelledArtist;
      case depositSubmitted:
        return to == confirmed || to == accepted || to == cancelledArtist;
      case confirmed:
        return to == completed || to == noShow || to == cancelledArtist;
    }
    return false;
  }

  static bool clientMay(String from, String to) {
    if (from == to) return true;
    if (from == accepted) return to == depositSubmitted || to == cancelledClient;
    if (from == requested || from == depositSubmitted || from == confirmed) {
      return to == cancelledClient;
    }
    return false;
  }

  static String label(String s, bool am) {
    switch (s) {
      case requested:
        return am ? 'ጥያቄ ተልኳል' : 'Requested';
      case accepted:
        return am ? 'ተቀባይነት አግኝቷል · ቅድመ ክፍያ ይጠበቃል' : 'Accepted · deposit due';
      case depositSubmitted:
        return am ? 'ክፍያ ተልኳል · ማረጋገጫ ይጠበቃል' : 'Deposit sent · awaiting check';
      case confirmed:
        return am ? 'ተረጋግጧል' : 'Confirmed';
      case completed:
        return am ? 'ተጠናቋል' : 'Completed';
      case declined:
        return am ? 'ተቀባይነት አላገኘም' : 'Declined';
      case cancelledClient:
        return am ? 'በደንበኛው ተሰርዟል' : 'Cancelled by client';
      case cancelledArtist:
        return am ? 'በባለሙያው ተሰርዟል' : 'Cancelled by artist';
      case noShow:
        return am ? 'አልመጡም' : 'No-show';
      case expired:
        return am ? 'ጊዜው አልፏል' : 'Expired';
    }
    return s;
  }
}

class Booking {
  final String id;
  final String ref;
  final String clientUid;
  final String clientName;
  final String clientPhone;
  final String clientEmail;
  final String artistUid;
  final String artistName;
  final String artistHandle;
  final List<BookingItem> items;
  final int people;
  final int total;
  final bool totalIsFrom;
  final bool hasHiddenPrice;
  final int travelFee;
  final int durationMin;
  final String date; // yyyy-MM-dd (Addis)
  final int startMin;
  final DateTime? startAt;
  final String place; // studio | home | venue
  final String subCity;
  final String area;
  final String landmark;
  final String notes;
  final int depositPercent;
  final int depositAmount;
  final String policy;
  final String status;
  final Map<String, dynamic> paymentInstructions;
  final Map<String, dynamic> payment;
  final String declineReason;
  final String cancelReason;
  final bool reviewed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Booking({
    required this.id,
    required this.ref,
    required this.clientUid,
    required this.clientName,
    required this.clientPhone,
    required this.clientEmail,
    required this.artistUid,
    required this.artistName,
    required this.artistHandle,
    required this.items,
    required this.people,
    required this.total,
    required this.totalIsFrom,
    required this.hasHiddenPrice,
    required this.travelFee,
    required this.durationMin,
    required this.date,
    required this.startMin,
    required this.startAt,
    required this.place,
    required this.subCity,
    required this.area,
    required this.landmark,
    required this.notes,
    required this.depositPercent,
    required this.depositAmount,
    required this.policy,
    required this.status,
    required this.paymentInstructions,
    required this.payment,
    required this.declineReason,
    required this.cancelReason,
    required this.reviewed,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOpen => BookingStatus.open.contains(status);
  String get servicesLabel => items.map((i) => i.name).join(', ');
  int get endMin => startMin + durationMin;

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return Booking(
      id: d.id,
      ref: _s(m['ref']),
      clientUid: _s(m['clientUid']),
      clientName: _s(m['clientName']),
      clientPhone: _s(m['clientPhone']),
      clientEmail: _s(m['clientEmail']),
      artistUid: _s(m['artistUid']),
      artistName: _s(m['artistName']),
      artistHandle: _s(m['artistHandle']),
      items: (m['items'] is List ? m['items'] as List : const [])
          .whereType<Map>()
          .map((e) => BookingItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      people: _i(m['people'], 1),
      total: _i(m['total']),
      totalIsFrom: _b(m['totalIsFrom']),
      hasHiddenPrice: _b(m['hasHiddenPrice']),
      travelFee: _i(m['travelFee']),
      durationMin: _i(m['durationMin'], 60),
      date: _s(m['date']),
      startMin: _i(m['startMin']),
      startAt: tsToDate(m['startAt']),
      place: _s(m['place'], 'studio'),
      subCity: _s(m['subCity']),
      area: _s(m['area']),
      landmark: _s(m['landmark']),
      notes: _s(m['notes']),
      depositPercent: _i(m['depositPercent']),
      depositAmount: _i(m['depositAmount']),
      policy: _s(m['policy'], 'standard'),
      status: _s(m['status'], BookingStatus.requested),
      paymentInstructions: _m(m['paymentInstructions']),
      payment: _m(m['payment']),
      declineReason: _s(m['declineReason']),
      cancelReason: _s(m['cancelReason']),
      reviewed: _b(m['reviewed']),
      createdAt: tsToDate(m['createdAt']),
      updatedAt: tsToDate(m['updatedAt']),
    );
  }
}

class Review {
  final String id; // = booking id
  final String studioUid;
  final String clientUid;
  final String clientName;
  final int rating;
  final int skill;
  final int punctuality;
  final int hygiene;
  final int value;
  final String text;
  final String reply;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.studioUid,
    required this.clientUid,
    required this.clientName,
    required this.rating,
    required this.skill,
    required this.punctuality,
    required this.hygiene,
    required this.value,
    required this.text,
    required this.reply,
    this.createdAt,
  });

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return Review(
      id: d.id,
      studioUid: _s(m['studioUid']),
      clientUid: _s(m['clientUid']),
      clientName: _s(m['clientName']),
      rating: _i(m['rating'], 5),
      skill: _i(m['skill'], 5),
      punctuality: _i(m['punctuality'], 5),
      hygiene: _i(m['hygiene'], 5),
      value: _i(m['value'], 5),
      text: _s(m['text']),
      reply: _s(m['reply']),
      createdAt: tsToDate(m['createdAt']),
    );
  }
}

// ---------------------------------------------------------------- chat

class Chat {
  final String id;
  final List<String> participants;
  final Map<String, String> names;
  final Map<String, String> photos;
  final String lastMessage;
  final String lastSenderUid;
  final DateTime? updatedAt;
  final Map<String, int> unread;

  const Chat({
    required this.id,
    required this.participants,
    required this.names,
    required this.photos,
    required this.lastMessage,
    required this.lastSenderUid,
    required this.updatedAt,
    required this.unread,
  });

  String otherUid(String me) =>
      participants.firstWhere((p) => p != me, orElse: () => me);
  String otherName(String me) => names[otherUid(me)] ?? 'A Studio member';
  String otherPhoto(String me) => photos[otherUid(me)] ?? '';
  int unreadFor(String me) => unread[me] ?? 0;

  factory Chat.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    final unreadRaw = _m(m['unread']);
    return Chat(
      id: d.id,
      participants: _ls(m['participants']),
      names: _m(m['names']).map((k, v) => MapEntry(k, _s(v))),
      photos: _m(m['photos']).map((k, v) => MapEntry(k, _s(v))),
      lastMessage: _s(m['lastMessage']),
      lastSenderUid: _s(m['lastSenderUid']),
      updatedAt: tsToDate(m['updatedAt']),
      unread: unreadRaw.map((k, v) => MapEntry(k, _i(v))),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final String kind; // text | image | booking | listing
  final String imageUrl;
  final String refId;
  final String refTitle;
  final String refSubtitle;
  final String refLink;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.kind,
    required this.imageUrl,
    required this.refId,
    required this.refTitle,
    required this.refSubtitle,
    required this.refLink,
    this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return ChatMessage(
      id: d.id,
      senderUid: _s(m['senderUid']),
      text: _s(m['text']),
      kind: _s(m['kind'], 'text'),
      imageUrl: _s(m['imageUrl']),
      refId: _s(m['refId']),
      refTitle: _s(m['refTitle']),
      refSubtitle: _s(m['refSubtitle']),
      refLink: _s(m['refLink']),
      createdAt: tsToDate(m['createdAt']),
    );
  }
}

// ---------------------------------------------------------------- notifications

class AppNotification {
  final String id;
  final String toUid;
  final String fromUid;
  final String fromName;
  final String type;
  final String title;
  final String body;
  final String link;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.toUid,
    required this.fromUid,
    required this.fromName,
    required this.type,
    required this.title,
    required this.body,
    required this.link,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return AppNotification(
      id: d.id,
      toUid: _s(m['toUid']),
      fromUid: _s(m['fromUid']),
      fromName: _s(m['fromName']),
      type: _s(m['type']),
      title: _s(m['title']),
      body: _s(m['body']),
      link: _s(m['link']),
      read: _b(m['read']),
      createdAt: tsToDate(m['createdAt']),
    );
  }
}

// ---------------------------------------------------------------- shop

class Listing {
  final String id;
  final String sellerUid;
  final String sellerName;
  final String sellerHandle;
  final bool official;
  final String title;
  final String category;
  final String brand;
  final String condition;
  final int price;
  final bool negotiable;
  final int quantity;
  final String subCity;
  final String description;
  final List<String> photos;
  final String expiry; // yyyy-MM or ''
  final String whatsapp;
  final String telegram;
  final String status; // active | sold | removed
  final DateTime? createdAt;

  const Listing({
    required this.id,
    required this.sellerUid,
    required this.sellerName,
    required this.sellerHandle,
    required this.official,
    required this.title,
    required this.category,
    required this.brand,
    required this.condition,
    required this.price,
    required this.negotiable,
    required this.quantity,
    required this.subCity,
    required this.description,
    required this.photos,
    required this.expiry,
    required this.whatsapp,
    required this.telegram,
    required this.status,
    this.createdAt,
  });

  String get cover => photos.isEmpty ? '' : photos.first;
  bool get isPreLoved => condition == 'gently_used' || condition == 'used';

  factory Listing.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return Listing(
      id: d.id,
      sellerUid: _s(m['sellerUid']),
      sellerName: _s(m['sellerName']),
      sellerHandle: _s(m['sellerHandle']),
      official: _b(m['official']),
      title: _s(m['title']),
      category: _s(m['category'], 'makeup'),
      brand: _s(m['brand']),
      condition: _s(m['condition'], 'new_sealed'),
      price: _i(m['price']),
      negotiable: _b(m['negotiable']),
      quantity: _i(m['quantity'], 1),
      subCity: _s(m['subCity']),
      description: _s(m['description']),
      photos: _ls(m['photos']),
      expiry: _s(m['expiry']),
      whatsapp: _s(m['whatsapp']),
      telegram: _s(m['telegram']),
      status: _s(m['status'], 'active'),
      createdAt: tsToDate(m['createdAt']),
    );
  }
}

// ---------------------------------------------------------------- admin

class ActivityEntry {
  final String id;
  final String actorUid;
  final String actorName;
  final String type;
  final String targetType;
  final String targetId;
  final String summary;
  final DateTime? createdAt;

  const ActivityEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.type,
    required this.targetType,
    required this.targetId,
    required this.summary,
    this.createdAt,
  });

  factory ActivityEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return ActivityEntry(
      id: d.id,
      actorUid: _s(m['actorUid']),
      actorName: _s(m['actorName']),
      type: _s(m['type']),
      targetType: _s(m['targetType']),
      targetId: _s(m['targetId']),
      summary: _s(m['summary']),
      createdAt: tsToDate(m['createdAt']),
    );
  }
}

class Report {
  final String id;
  final String reporterUid;
  final String reporterName;
  final String targetType;
  final String targetId;
  final String targetLabel;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;

  const Report({
    required this.id,
    required this.reporterUid,
    required this.reporterName,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.reason,
    required this.details,
    required this.status,
    this.createdAt,
  });

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return Report(
      id: d.id,
      reporterUid: _s(m['reporterUid']),
      reporterName: _s(m['reporterName']),
      targetType: _s(m['targetType']),
      targetId: _s(m['targetId']),
      targetLabel: _s(m['targetLabel']),
      reason: _s(m['reason']),
      details: _s(m['details']),
      status: _s(m['status'], 'open'),
      createdAt: tsToDate(m['createdAt']),
    );
  }
}
