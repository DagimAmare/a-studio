import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/catalog.dart';
import '../core/validators.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/listing_service.dart';
import '../services/media_service.dart';
import '../services/session.dart';
import '../theme/colors.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';

/// Words that send a listing to Backstage for a human look.
const List<String> _flagWords = [
  'mercury', 'bleach', 'whitening', 'lightening', 'replica', 'fake', 'copy', 'first copy',
  'used mascara', 'used lipstick', 'prescription', 'steroid', 'hydroquinone',
];

class ListingEditorScreen extends StatelessWidget {
  final String? listingId;
  const ListingEditorScreen({super.key, this.listingId});

  @override
  Widget build(BuildContext context) {
    return SignedInGate(builder: (context) {
      final s = Session.instance;
      if (!s.isArtist && !s.isAdmin) {
        return EmptyState(
          icon: Icons.storefront_outlined,
          title: context.tr('Selling is open to artists on A Studio', 'መሸጥ ለኤ ስቱዲዮ ባለሙያዎች ክፍት ነው'),
          body: context.tr('Open your studio to list gear and products. Clients will be able to sell later.',
              'እቃዎችን ለመሸጥ ስቱዲዮዎን ይክፈቱ። ደንበኞች ወደፊት መሸጥ ይችላሉ።'),
          action: FilledButton(
            onPressed: () => context.go('/desk/setup'),
            child: Text(context.tr('Open my studio', 'ስቱዲዮዬን ክፈት')),
          ),
        );
      }
      if (listingId == null) return const _Editor(existing: null);
      return _EditorLoader(id: listingId!);
    });
  }
}

/// Loads the listing once, so live updates never reset the form mid-edit.
class _EditorLoader extends StatefulWidget {
  final String id;
  const _EditorLoader({required this.id});
  @override
  State<_EditorLoader> createState() => _EditorLoaderState();
}

class _EditorLoaderState extends State<_EditorLoader> {
  late final Future<Listing?> _future = ListingService.watch(widget.id).first;

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return FutureBuilder<Listing?>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(context.tr('Could not open this listing.', 'እቃውን መክፈት አልተቻለም።'));
        if (snap.connectionState != ConnectionState.done) return const Loading();
        final l = snap.data;
        if (l == null || (l.sellerUid != s.uid && !s.isAdmin)) {
          return EmptyState(icon: Icons.lock_outline, title: context.tr('You cannot edit this listing', 'ይህን እቃ ማስተካከል አይችሉም'));
        }
        return _Editor(existing: l);
      },
    );
  }
}

class _Editor extends StatefulWidget {
  final Listing? existing;
  const _Editor({required this.existing});
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  Listing? get e => widget.existing;
  late final List<String> _photos = [...?e?.photos];
  final List<String> _removed = [];
  late final _title = TextEditingController(text: e?.title ?? '');
  late final _brand = TextEditingController(text: e?.brand ?? '');
  late final _price = TextEditingController(text: (e?.price ?? 0) > 0 ? '${e!.price}' : '');
  late final _qty = TextEditingController(text: '${e?.quantity ?? 1}');
  late final _desc = TextEditingController(text: e?.description ?? '');
  late final _whatsapp = TextEditingController(
      text: e?.whatsapp ?? (Session.instance.studio?.whatsapp ?? Session.instance.profile?.phone ?? ''));
  late final _telegram = TextEditingController(text: e?.telegram ?? (Session.instance.studio?.telegram ?? ''));
  late String _category = e?.category ?? 'makeup';
  late String _condition = e?.condition ?? 'new_sealed';
  late String _subCity = e?.subCity ?? '';
  late bool _negotiable = e?.negotiable ?? false;
  late bool _official = e?.official ?? false;
  late String _expiry = e?.expiry ?? '';
  bool _rules = false;
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _brand, _price, _qty, _desc, _whatsapp, _telegram]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhotos() async {
    try {
      final picked = await MediaService.pickImages();
      if (picked.isEmpty || !mounted) return;
      final room = 8 - _photos.length;
      if (room <= 0) {
        toast(context, context.tr('Up to 8 photos.', 'እስከ 8 ፎቶዎች።'));
        return;
      }
      setState(() {
        _uploading = true;
        _progress = 0;
      });
      for (final p in picked.take(room)) {
        final up = await MediaService.upload(p, onProgress: (f) {
          if (mounted) setState(() => _progress = f);
        });
        if (mounted) setState(() => _photos.add(up.url));
      }
    } catch (err) {
      if (mounted) toast(context, AuthService.friendlyError(err));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse('$_expiry-01') ?? DateTime(now.year + 1, now.month, 1);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 8, 12, 31),
      initialDate: initial.isBefore(DateTime(now.year - 1)) ? now : initial,
      initialDatePickerMode: DatePickerMode.year,
      helpText: context.tr('Expiry month (any day in it)', 'የሚያበቃበት ወር'),
    );
    if (picked == null) return;
    setState(() => _expiry = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}');
  }

  bool get _isCosmetic => _category == 'makeup' || _category == 'skincare' || _category == 'nails';

  Future<void> _save() async {
    final s = Session.instance;
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final qty = int.tryParse(_qty.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    String? problem;
    if (_photos.isEmpty) {
      problem = context.tr('Add at least one photo.', 'ቢያንስ አንድ ፎቶ ያክሉ።');
    } else if (_title.text.trim().length < 3) {
      problem = context.tr('Give it a clear title.', 'ግልጽ ርዕስ ይስጡት።');
    } else if (price <= 0) {
      problem = context.tr('Enter a price.', 'ዋጋ ያስገቡ።');
    } else if (_subCity.isEmpty) {
      problem = context.tr('Choose where buyers pick it up.', 'ገዢዎች የት እንደሚረከቡ ይምረጡ።');
    } else if (_isCosmetic && _expiry.isEmpty && _condition != 'gently_used' && _condition != 'used') {
      problem = context.tr('Add the expiry month printed on the product.', 'በምርቱ ላይ የታተመውን የሚያበቃበት ወር ያስገቡ።');
    } else if (!_rules) {
      problem = context.tr('Please confirm the item follows the house rules.', 'እቃው ሕጎቹን እንደሚከተል ያረጋግጡ።');
    }
    if (_expiry.isNotEmpty) {
      final exp = DateTime.tryParse('$_expiry-01');
      final now = DateTime.now();
      if (exp != null && DateTime(exp.year, exp.month + 1, 1).isBefore(now)) {
        problem = context.tr('This product has expired, so it cannot be listed.', 'ይህ ምርት ጊዜው አልፏል፣ ስለዚህ ሊለጠፍ አይችልም።');
      }
    }
    if (_isCosmetic && (_condition == 'gently_used' || _condition == 'used') && _category != 'nails') {
      problem = context.tr('Opened or used makeup and skincare cannot be sold. Tools and equipment can.',
          'የተከፈቱ ወይም ያገለገሉ ሜካፕ እና የቆዳ ምርቶች አይሸጡም። መሣሪያዎች ይቻላሉ።');
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _error = null);
    final text = '${_title.text} ${_brand.text} ${_desc.text}'.toLowerCase();
    final flagged = _flagWords.any(text.contains);
    final wa = _whatsapp.text.trim();
    final data = <String, dynamic>{
      'sellerUid': e?.sellerUid ?? s.uid,
      'sellerName': e?.sellerName ?? (s.studio?.name ?? s.displayName),
      'sellerHandle': e?.sellerHandle ?? (s.studio?.handle ?? ''),
      'official': s.isAdmin ? _official : (e?.official ?? false),
      'title': _title.text.trim(),
      'category': _category,
      'brand': _brand.text.trim(),
      'condition': _condition,
      'price': price,
      'negotiable': _negotiable,
      'quantity': qty < 1 ? 1 : qty,
      'subCity': _subCity,
      'description': _desc.text.trim(),
      'photos': _photos,
      'expiry': _expiry,
      'whatsapp': wa.isEmpty ? '' : (normalizeEthiopianPhone(wa) ?? wa),
      'telegram': telegramUsername(_telegram.text),
      'flagged': flagged,
    };
    final id = await Busy.run<String>(context, () async {
      if (e == null) return ListingService.create(data);
      await ListingService.update(e!.id, data);
      return e!.id;
    }, success: e == null ? context.tr('Your item is live', 'እቃዎ ተለጥፏል') : context.tr('Saved', 'ተቀምጧል'));
    if (id == null || !mounted) return;
    for (final url in _removed) {
      MediaService.delete(url);
    }
    context.go('/shop/$id');
  }

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    final t = Theme.of(context);
    final banned = am ? kBannedItemsAm : kBannedItemsEn;
    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        PageBody(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(e == null ? context.tr('Sell an item', 'እቃ ይሽጡ') : context.tr('Edit listing', 'እቃውን አስተካክል'),
                  kicker: context.tr('The Vanity', 'የውበት ሱቅ')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(context.tr('Photos (up to 8)', 'ፎቶዎች (እስከ 8)'), style: t.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      for (var i = 0; i < _photos.length; i++)
                        Stack(children: [
                          NetImage(_photos[i], width: 96, height: 96, radius: BorderRadius.circular(14)),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: InkWell(
                              onTap: () => setState(() {
                                _removed.add(_photos[i]);
                                _photos.removeAt(i);
                              }),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.espresso,
                                child: Icon(Icons.close, size: 14, color: AppColors.milk),
                              ),
                            ),
                          ),
                          if (i == 0)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Pill(context.tr('Cover', 'ሽፋን'), background: AppColors.milk),
                            ),
                        ]),
                      if (_photos.length < 8)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _uploading ? null : _addPhotos,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.oat,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.latte),
                            ),
                            child: _uploading
                                ? Center(child: CircularProgressIndicator(value: _progress > 0 ? _progress : null, strokeWidth: 2))
                                : const Icon(Icons.add_a_photo_outlined, color: AppColors.cocoa),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: context.tr('Title', 'ርዕስ'),
                        hintText: context.tr('18-inch ring light with stand', 'ባለ 18 ኢንች ሪንግ ላይት ከመቆሚያ ጋር'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: SelectField<String>(
                          label: context.tr('Category', 'ዘርፍ'),
                          value: _category,
                          items: [for (final c in kListingCategories) (c.id, c.label(am))],
                          onChanged: (v) => setState(() => _category = v ?? _category),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SelectField<String>(
                          label: context.tr('Condition', 'ሁኔታ'),
                          value: _condition,
                          items: [for (final c in kConditions) (c.id, c.label(am))],
                          onChanged: (v) => setState(() => _condition = v ?? _condition),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _brand,
                      decoration: InputDecoration(labelText: context.tr('Brand (optional)', 'ብራንድ (አማራጭ)')),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: context.tr('Price', 'ዋጋ'), prefixText: 'Br '),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _qty,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: context.tr('Quantity', 'ብዛት')),
                        ),
                      ),
                    ]),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _negotiable,
                      onChanged: (v) => setState(() => _negotiable = v),
                      title: Text(context.tr('Price is negotiable', 'ዋጋው ድርድር አለው')),
                    ),
                    SelectField<String>(
                      label: context.tr('Pickup sub-city', 'የመረከቢያ ክፍለ ከተማ'),
                      value: _subCity,
                      items: [for (final c in kSubCities) (c.id, c.label(am))],
                      onChanged: (v) => setState(() => _subCity = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(_expiry.isEmpty
                          ? context.tr('Expiry month (for cosmetics)', 'የሚያበቃበት ወር (ለመዋቢያዎች)')
                          : '${context.tr('Expires', 'የሚያበቃው')} $_expiry'),
                      trailing: Wrap(children: [
                        if (_expiry.isNotEmpty)
                          IconButton(onPressed: () => setState(() => _expiry = ''), icon: const Icon(Icons.clear)),
                        TextButton(onPressed: _pickExpiry, child: Text(context.tr('Set', 'አስቀምጥ'))),
                      ]),
                    ),
                    TextField(
                      controller: _desc,
                      maxLines: 5,
                      maxLength: 1200,
                      decoration: InputDecoration(
                        labelText: context.tr('Description', 'መግለጫ'),
                        hintText: context.tr('Shade or size, how long you used it, what is included...', 'ቀለም ወይም መጠን፣ ምን ያህል እንደተጠቀሙበት...'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _whatsapp,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: context.tr('WhatsApp for buyers (optional)', 'ለገዢዎች ዋትስአፕ (አማራጭ)')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telegram,
                      decoration: InputDecoration(labelText: context.tr('Telegram for buyers (optional)', 'ለገዢዎች ቴሌግራም (አማራጭ)')),
                    ),
                    if (Session.instance.isAdmin)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _official,
                        onChanged: (v) => setState(() => _official = v),
                        title: Text(context.tr('Sell as the official A Studio shop', 'እንደ ኤ ስቱዲዮ ይፋዊ ሱቅ ይሽጡ')),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: AppColors.petal.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Never allowed on The Vanity', 'በሱቁ ፈጽሞ የማይፈቀዱ'), style: t.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    for (final b in banned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('·  '),
                          Expanded(child: Text(b)),
                        ]),
                      ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _rules,
                      onChanged: (v) => setState(() => _rules = v ?? false),
                      title: Text(context.tr(
                          'This item is genuine, follows these rules, and is mine to sell. I am responsible for it, not A Studio.',
                          'ይህ እቃ እውነተኛ ነው፣ እነዚህን ሕጎች ይከተላል፣ እና የምሸጠው የራሴን ነው። ኃላፊነቱ የእኔ እንጂ የኤ ስቱዲዮ አይደለም።')),
                    ),
                  ]),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                ),
              const SizedBox(height: 16),
              Row(children: [
                TextButton(
                  onPressed: () => context.go(e == null ? '/shop' : '/shop/${e!.id}'),
                  child: Text(context.tr('Cancel', 'ይቅር')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _uploading ? null : _save,
                  child: Text(e == null ? context.tr('Post listing', 'ለጥፍ') : context.tr('Save', 'አስቀምጥ')),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
