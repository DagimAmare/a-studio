/// Fixed lists the whole app shares: sub-cities, services, occasions,
/// shop categories, policies. Labels carry English and Amharic.
library;

class Option {
  final String id;
  final String en;
  final String am;
  const Option(this.id, this.en, this.am);
  String label(bool amharic) => amharic ? am : en;
}

const List<Option> kSubCities = [
  Option('bole', 'Bole', 'ቦሌ'),
  Option('kirkos', 'Kirkos', 'ቂርቆስ'),
  Option('yeka', 'Yeka', 'የካ'),
  Option('arada', 'Arada', 'አራዳ'),
  Option('lideta', 'Lideta', 'ልደታ'),
  Option('nifas-silk', 'Nifas Silk-Lafto', 'ንፋስ ስልክ ላፍቶ'),
  Option('kolfe', 'Kolfe Keranio', 'ኮልፌ ቀራኒዮ'),
  Option('gullele', 'Gullele', 'ጉለሌ'),
  Option('addis-ketema', 'Addis Ketema', 'አዲስ ከተማ'),
  Option('akaky', 'Akaky Kaliti', 'አቃቂ ቃሊቲ'),
  Option('lemi-kura', 'Lemi Kura', 'ለሚ ኩራ'),
];

const List<Option> kServiceCategories = [
  Option('makeup', 'Makeup', 'ሜካፕ'),
  Option('nails', 'Nails', 'ጥፍር'),
  Option('hair', 'Hair', 'ፀጉር'),
  Option('braids', 'Braids', 'ሹሩባ'),
  Option('lashes', 'Lashes', 'ሽፋሽፍት'),
  Option('brows', 'Brows', 'ቅንድብ'),
  Option('henna', 'Henna', 'ሂና'),
  Option('skin', 'Skincare', 'የቆዳ እንክብካቤ'),
];

const List<Option> kOccasions = [
  Option('bridal', 'Bridal', 'ሙሽራ'),
  Option('melse', 'Melse', 'መልስ'),
  Option('graduation', 'Graduation', 'ምረቃ'),
  Option('birthday', 'Birthday', 'ልደት'),
  Option('holiday', 'Holiday', 'በዓል'),
  Option('night-out', 'Night out', 'ምሽት ዝግጅት'),
  Option('photoshoot', 'Photoshoot', 'ፎቶ ቀረጻ'),
  Option('everyday', 'Everyday', 'የዘወትር'),
];

class ServiceTemplate {
  final String name;
  final String category;
  final int minutes;
  const ServiceTemplate(this.name, this.category, this.minutes);
}

const List<ServiceTemplate> kServiceTemplates = [
  ServiceTemplate('Soft glam', 'makeup', 90),
  ServiceTemplate('Full glam', 'makeup', 120),
  ServiceTemplate('Bridal makeup', 'makeup', 150),
  ServiceTemplate('Bridal trial', 'makeup', 90),
  ServiceTemplate('Melse look', 'makeup', 120),
  ServiceTemplate('Gel nails', 'nails', 60),
  ServiceTemplate('Acrylic set', 'nails', 90),
  ServiceTemplate('Pedicure', 'nails', 60),
  ServiceTemplate('Shuruba braids', 'braids', 240),
  ServiceTemplate('Silk press', 'hair', 90),
  ServiceTemplate('Lash extensions', 'lashes', 120),
  ServiceTemplate('Brow shaping', 'brows', 30),
  ServiceTemplate('Henna', 'henna', 60),
];

const List<Option> kListingCategories = [
  Option('makeup', 'Makeup', 'ሜካፕ'),
  Option('skincare', 'Skincare', 'የቆዳ እንክብካቤ'),
  Option('nails', 'Nails', 'ጥፍር'),
  Option('hair', 'Hair and wigs', 'ፀጉር እና ዊግ'),
  Option('lashes', 'Lashes and brows', 'ሽፋሽፍት እና ቅንድብ'),
  Option('tools', 'Brushes and tools', 'ብሩሽ እና መሣሪያዎች'),
  Option('equipment', 'Equipment', 'መሣሪያ'),
  Option('kits', 'Kits and cases', 'ኪት እና ሳጥን'),
];

const List<Option> kConditions = [
  Option('new_sealed', 'New, sealed', 'አዲስ፣ ያልተከፈተ'),
  Option('new_open', 'New, open box', 'አዲስ፣ የተከፈተ'),
  Option('gently_used', 'Gently used', 'በጥቂቱ ያገለገለ'),
  Option('used', 'Used', 'ያገለገለ'),
];

class CancellationPolicy {
  final String id;
  final String en;
  final String am;
  final String detailEn;
  final String detailAm;
  const CancellationPolicy(this.id, this.en, this.am, this.detailEn, this.detailAm);
}

const List<CancellationPolicy> kPolicies = [
  CancellationPolicy(
      'flexible',
      'Flexible',
      'ቀላል',
      'Full deposit refund if you cancel at least 24 hours before.',
      'ከ24 ሰዓት በፊት ከሰረዙ ቅድመ ክፍያው ሙሉ በሙሉ ይመለሳል።'),
  CancellationPolicy(
      'standard',
      'Standard',
      'መደበኛ',
      'Full refund up to 72 hours before; half the deposit after that.',
      'እስከ 72 ሰዓት በፊት ሙሉ ይመለሳል፤ ከዚያ በኋላ ግማሹ።'),
  CancellationPolicy(
      'bridal',
      'Bridal',
      'የሙሽራ',
      'The deposit is non-refundable within 14 days of the date.',
      'ከቀኑ 14 ቀን በፊት ባለው ጊዜ ውስጥ ቅድመ ክፍያው አይመለስም።'),
];

Option optionById(List<Option> list, String? id) => list.firstWhere(
    (o) => o.id == id,
    orElse: () => Option(id ?? '', id ?? '', id ?? ''));

CancellationPolicy policyById(String? id) =>
    kPolicies.firstWhere((p) => p.id == id, orElse: () => kPolicies[1]);

/// Things that may never be sold on The Vanity, shown before listing.
const List<String> kBannedItemsEn = [
  'Opened mascara, lip products, foundation or eyeliner',
  'Used lashes, sponges or puffs',
  'Opened skincare',
  'Products past their expiry date',
  'Skin bleaching or mercury products, prescription medicines',
  'Counterfeits',
];
const List<String> kBannedItemsAm = [
  'የተከፈቱ ማስካራ፣ የከንፈር ምርቶች፣ ፋውንዴሽን ወይም አይላይነር',
  'ያገለገሉ ሽፋሽፍቶች፣ ስፖንጆች',
  'የተከፈቱ የቆዳ እንክብካቤ ምርቶች',
  'ጊዜያቸው ያለፈባቸው ምርቶች',
  'የቆዳ ማንጫ ወይም ሜርኩሪ ያላቸው ምርቶች፣ በሐኪም ትዕዛዝ የሚሰጡ መድኃኒቶች',
  'ሐሰተኛ ምርቶች',
];
