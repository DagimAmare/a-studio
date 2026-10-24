import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/studio_service.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import 'desk_screen.dart';

class PaymentsTab extends StatefulWidget {
  final Studio studio;
  const PaymentsTab({super.key, required this.studio});
  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  late int _deposit = widget.studio.depositPercent;
  late String _policy = widget.studio.cancellationPolicy;
  late final _travel = TextEditingController(
      text: widget.studio.travelFee > 0 ? '${widget.studio.travelFee}' : '');
  final _telebirr = TextEditingController();
  final _cbe = TextEditingController();
  final _cbeName = TextEditingController();
  final _note = TextEditingController();
  bool _loaded = false;

  int get _minDeposit => widget.studio.homeVisits ? 20 : 0;

  @override
  void initState() {
    super.initState();
    if (_deposit < _minDeposit) _deposit = _minDeposit;
    StudioService.paymentDetails().then((p) {
      if (!mounted) return;
      setState(() {
        _telebirr.text = p.telebirr;
        _cbe.text = p.cbeAccount;
        _cbeName.text = p.cbeName;
        _note.text = p.note;
        _loaded = true;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _travel.dispose();
    _telebirr.dispose();
    _cbe.dispose();
    _cbeName.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_deposit > 0 && _telebirr.text.trim().isEmpty && _cbe.text.trim().isEmpty) {
      toast(context, context.tr('Add a Telebirr number or a CBE account so clients can pay the deposit.',
          'ደንበኞች ቅድመ ክፍያ እንዲከፍሉ የቴሌብር ቁጥር ወይም የንግድ ባንክ ሂሳብ ያስገቡ።'));
      return;
    }
    final travel = int.tryParse(_travel.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    await Busy.run(context, () async {
      await StudioService.update({
        'depositPercent': _deposit,
        'cancellationPolicy': _policy,
        'travelFee': travel,
      }, log: 'policy_update');
      await StudioService.savePaymentDetails(PaymentDetails(
        telebirr: _telebirr.text.trim(),
        cbeAccount: _cbe.text.replaceAll(' ', '').trim(),
        cbeName: _cbeName.text.trim(),
        note: _note.text.trim(),
      ));
    }, success: context.tr('Saved', 'ተቀምጧል'));
  }

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    final example = 2500 * _deposit ~/ 100;
    return DeskPage(
      title: context.tr('Deposits & policy', 'ቅድመ ክፍያ እና ፖሊሲ'),
      intro: context.tr(
          'For now clients pay the deposit straight to you by Telebirr or CBE and enter the transaction reference; you confirm it here. A Studio never holds the money.',
          'ለጊዜው ደንበኞች ቅድመ ክፍያውን በቀጥታ በቴሌብር ወይም በንግድ ባንክ ይከፍሉዎታል፣ የግብይት ማጣቀሻውን ያስገባሉ፤ እርስዎ እዚህ ያረጋግጣሉ። ኤ ስቱዲዮ ገንዘቡን አይዝም።'),
      trailing: FilledButton(onPressed: _loaded ? _save : null, child: Text(context.tr('Save', 'አስቀምጥ'))),
      children: [
        DeskCard(
          title: context.tr('Deposit', 'ቅድመ ክፍያ'),
          children: [
            Text(_deposit == 0
                ? context.tr('No deposit. Bookings confirm when you accept.', 'ቅድመ ክፍያ የለም። ሲቀበሉ ቀጠሮው ይረጋገጣል።')
                : context.tr('$_deposit% of the total. On a Br 2,500 booking that is ${birr(example)}.',
                    'ከጠቅላላው $_deposit%። በ2,500 ብር ቀጠሮ ላይ ${birr(example)} ነው።')),
            Slider(
              value: _deposit.toDouble(),
              min: 0,
              max: 50,
              divisions: 10,
              label: '$_deposit%',
              onChanged: (v) => setState(() => _deposit = v.round() < _minDeposit ? _minDeposit : v.round()),
            ),
            if (_minDeposit > 0)
              Text(
                context.tr('Home visits need at least 20%, which keeps fake bookings away.',
                    'የቤት ጉብኝት ቢያንስ 20% ይፈልጋል፣ ይህም ሐሰተኛ ቀጠሮዎችን ይከላከላል።'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        DeskCard(
          title: context.tr('Where clients pay you', 'ደንበኞች የሚከፍሉዎት የት ነው'),
          children: [
            if (!_loaded) const LinearProgressIndicator(),
            TextField(
              controller: _telebirr,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.tr('Telebirr number', 'የቴሌብር ቁጥር'), hintText: '0911 234 567'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cbe,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('CBE account number', 'የንግድ ባንክ ሂሳብ ቁጥር')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cbeName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.tr('Name on the account', 'የሂሳቡ ባለቤት ስም')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.tr('Note for clients (optional)', 'ለደንበኞች ማስታወሻ (አማራጭ)'),
                hintText: context.tr('Write your booking reference in the payment reason', 'በክፍያ ምክንያት ላይ የቀጠሮ ቁጥርዎን ይጻፉ'),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.lock_outline, size: 16, color: AppColors.taupe),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('Private. A client sees these only after you accept her booking.',
                      'የግል ነው። ደንበኛ የምታየው ቀጠሮዋን ከተቀበሉ በኋላ ብቻ ነው።'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ]),
          ],
        ),
        DeskCard(
          title: context.tr('Cancellation policy', 'የስረዛ ፖሊሲ'),
          children: [
            for (final p in kPolicies)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => setState(() => _policy = p.id),
                leading: Icon(
                  _policy == p.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _policy == p.id ? Theme.of(context).colorScheme.primary : AppColors.taupe,
                ),
                title: Text(am ? p.am : p.en),
                subtitle: Text(am ? p.detailAm : p.detailEn),
              ),
          ],
        ),
        if (widget.studio.homeVisits || widget.studio.venueVisits)
          DeskCard(
            title: context.tr('Travel fee', 'የትራንስፖርት ክፍያ'),
            children: [
              TextField(
                controller: _travel,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Added to home and venue bookings (Birr)', 'ለቤት እና ለዝግጅት ቦታ ቀጠሮዎች የሚጨመር (ብር)'),
                  prefixText: 'Br ',
                ),
              ),
            ],
          ),
      ],
    );
  }
}
