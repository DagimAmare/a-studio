import 'package:flutter/material.dart';

import '../core/validators.dart';
import '../l10n/tr.dart';
import '../services/auth_service.dart';

/// Confirms the phone on the profile with a one-time code.
Future<bool> showPhoneVerifyDialog(BuildContext context, String initialPhone) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PhoneVerifyDialog(initialPhone: initialPhone),
  );
  return ok ?? false;
}

class _PhoneVerifyDialog extends StatefulWidget {
  final String initialPhone;
  const _PhoneVerifyDialog({required this.initialPhone});
  @override
  State<_PhoneVerifyDialog> createState() => _PhoneVerifyDialogState();
}

class _PhoneVerifyDialogState extends State<_PhoneVerifyDialog> {
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _code = TextEditingController();
  String _channel = 'sms';
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = normalizeEthiopianPhone(_phone.text);
    if (phone == null) {
      setState(() => _error = context.tr('Enter an Ethiopian mobile number.', 'የኢትዮጵያ ሞባይል ቁጥር ያስገቡ።'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.sendPhoneCode(phone, purpose: 'verify', channel: _channel);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final phone = normalizeEthiopianPhone(_phone.text);
    if (phone == null || _code.text.trim().length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.verifyPhoneCode(phone, _code.text, purpose: 'verify');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AuthService.friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Verify your phone', 'ስልክዎን ያረጋግጡ')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phone,
              enabled: !_sent,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.tr('Phone number', 'ስልክ ቁጥር')),
            ),
            const SizedBox(height: 10),
            if (!_sent)
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('SMS'), selected: _channel == 'sms', onSelected: (_) => setState(() => _channel = 'sms')),
                ChoiceChip(
                    label: const Text('Telegram'),
                    selected: _channel == 'telegram',
                    onSelected: (_) => setState(() => _channel = 'telegram')),
              ])
            else
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                onSubmitted: (_) => _verify(),
                decoration: InputDecoration(labelText: context.tr('6-digit code', 'ባለ 6 አሃዝ ኮድ')),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(context.tr('Cancel', 'ይቅር'))),
        FilledButton(
          onPressed: _busy ? null : (_sent ? _verify : _send),
          child: Text(_sent ? context.tr('Verify', 'አረጋግጥ') : context.tr('Send code', 'ኮድ ላክ')),
        ),
      ],
    );
  }
}
