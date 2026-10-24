import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/validators.dart';
import '../l10n/tr.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

/// "?next=..&role=.." carried between the sign-in and sign-up pages.
String _carry(String next, String role) {
  final q = <String, String>{
    if (next.isNotEmpty) 'next': next,
    if (role.isNotEmpty) 'role': role,
  };
  return q.isEmpty ? '' : '?${Uri(queryParameters: q).query}';
}

String _lang() => LocaleController.instance.value.languageCode == 'am' ? 'am' : 'en';

class _AuthFrame extends StatelessWidget {
  final String kicker;
  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final List<Widget> below;
  const _AuthFrame({
    required this.kicker,
    required this.title,
    this.subtitle,
    required this.fields,
    this.below = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      children: [
        PageBody(
          maxWidth: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Monogram(size: 52)),
              const SizedBox(height: 18),
              Text(kicker.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: labelCaps(color: t.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: t.textTheme.headlineLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
                ),
              ),
              ...below,
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  final String? error;
  const _ErrorLine(this.error);
  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontFamily: 'DMSans')),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(context.tr('or', 'ወይም'), style: Theme.of(context).textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ]),
      );
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({required this.onPressed});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Text('G',
            style: TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.rouge)),
        label: Text(context.tr('Continue with Google', 'በGoogle ይቀጥሉ')),
      );
}

/// Checkbox row whose label can hold links to the legal pages.
class _ConsentBox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final InlineSpan label;
  const _ConsentBox({required this.value, required this.onChanged, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(label, style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextSpan _link(String text, String path) => TextSpan(
      text: text,
      style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
      recognizer: TapGestureRecognizer()..onTap = () => openSameTab(path),
    );

/// The consent block shared by sign-up and the Google welcome step.
class _Consents extends StatelessWidget {
  final bool terms;
  final bool storage;
  final bool marketing;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onStorage;
  final ValueChanged<bool> onMarketing;
  const _Consents({
    required this.terms,
    required this.storage,
    required this.marketing,
    required this.onTerms,
    required this.onStorage,
    required this.onMarketing,
  });

  @override
  Widget build(BuildContext context) {
    final am = context.isAm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConsentBox(
          value: terms,
          onChanged: onTerms,
          label: TextSpan(children: [
            TextSpan(text: am ? 'የኤ ስቱዲዮን ' : 'I agree to the A Studio '),
            _link(am ? 'የአገልግሎት ውል' : 'Terms of Use', AppConfig.termsPath),
            TextSpan(text: am ? ' እና ' : ' and '),
            _link(am ? 'የግላዊነት ፖሊሲ' : 'Privacy Policy', AppConfig.privacyPath),
            TextSpan(
                text: am
                    ? ' እቀበላለሁ። ኤ ስቱዲዮ ደንበኞችን እና ባለሙያዎችን የሚያገናኝ መድረክ ብቻ መሆኑን ተረድቻለሁ።'
                    : '. I understand A Studio only connects clients and independent artists.'),
          ]),
        ),
        _ConsentBox(
          value: storage,
          onChanged: onStorage,
          label: TextSpan(
              text: am
                  ? 'መረጃዬ በአውሮፓ በሚገኙ የGoogle Firebase አገልጋዮች እና በኤ ስቱዲዮ የድር አስተናጋጅ ላይ እንዲቀመጥ እስማማለሁ።'
                  : 'I agree that my data is stored on Google Firebase servers in Europe and on the A Studio web host.'),
        ),
        _ConsentBox(
          value: marketing,
          onChanged: onMarketing,
          label: TextSpan(
              text: am
                  ? 'የበዓል እና የሠርግ ወቅት ማስታወሻዎችን፣ የልደት ቀን ሰላምታ እና ቅናሾችን ላኩልኝ (አማራጭ)።'
                  : 'Send me holiday and wedding-season reminders, birthday wishes and offers (optional).'),
        ),
      ],
    );
  }
}

class _RolePicker extends StatelessWidget {
  final String role;
  final ValueChanged<String> onChanged;
  const _RolePicker({required this.role, required this.onChanged});
  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
        segments: [
          ButtonSegment(
              value: 'client',
              icon: const Icon(Icons.favorite_border),
              label: Text(context.tr('I want to book', 'ቀጠሮ መያዝ እፈልጋለሁ'))),
          ButtonSegment(
              value: 'artist',
              icon: const Icon(Icons.brush_outlined),
              label: Text(context.tr('I am an artist', 'ባለሙያ ነኝ'))),
        ],
        selected: {role},
        onSelectionChanged: (v) => onChanged(v.first),
      );
}

// ===================================================================== sign in

class SignInScreen extends StatefulWidget {
  final String next;
  final String role;
  const SignInScreen({super.key, this.next = '', this.role = ''});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _phoneMode = false;
  bool _codeSent = false;
  String _channel = 'sms';
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {bool keepBusy = true}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // The router moves on once the profile has loaded.
      if (!keepBusy && mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AuthService.friendlyError(e);
        });
      }
    }
  }

  void _signIn() {
    if (!isEmail(_email.text)) {
      setState(() => _error = context.tr('Enter the email you signed up with.', 'የተመዘገቡበትን ኢሜይል ያስገቡ።'));
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = context.tr('Enter your password.', 'የይለፍ ቃልዎን ያስገቡ።'));
      return;
    }
    _run(() => AuthService.signIn(_email.text, _password.text));
  }

  Future<void> _reset() async {
    if (!isEmail(_email.text)) {
      setState(() => _error = context.tr('Type your email above first, then tap "Forgot password".',
          'መጀመሪያ ኢሜይልዎን ከላይ ይጻፉ።'));
      return;
    }
    final sentText = context.tr('We sent a reset link to ${_email.text.trim()}. Check spam too.',
        'የመቀየሪያ ሊንክ ወደ ${_email.text.trim()} ልከናል።');
    await _run(() => AuthService.sendReset(_email.text), keepBusy: false);
    if (mounted && _error == null) toast(context, sentText);
  }

  Future<void> _sendCode() async {
    final phone = normalizeEthiopianPhone(_phone.text);
    if (phone == null) {
      setState(() => _error = context.tr('Enter an Ethiopian mobile number, like 0911 234 567.',
          'የኢትዮጵያ ሞባይል ቁጥር ያስገቡ፣ ለምሳሌ 0911 234 567።'));
      return;
    }
    await _run(() => AuthService.sendPhoneCode(phone, purpose: 'signin', channel: _channel), keepBusy: false);
    if (mounted && _error == null) setState(() => _codeSent = true);
  }

  void _verifyCode() {
    final phone = normalizeEthiopianPhone(_phone.text);
    if (phone == null || _code.text.trim().length < 4) return;
    _run(() => AuthService.verifyPhoneCode(phone, _code.text, purpose: 'signin'));
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.role == 'artist';
    return _AuthFrame(
      kicker: artist ? context.tr('For artists', 'ለባለሙያዎች') : context.tr('Welcome back', 'እንኳን ደህና መጡ'),
      title: context.tr('Sign in', 'ይግቡ'),
      subtitle: artist
          ? context.tr('Sign in to open your Studio Desk.', 'የስቱዲዮ ዴስክዎን ለመክፈት ይግቡ።')
          : null,
      fields: [
        if (!_phoneMode) ...[
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: context.tr('Email', 'ኢሜይል')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signIn(),
            decoration: InputDecoration(
              labelText: context.tr('Password', 'የይለፍ ቃል'),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _reset,
              child: Text(context.tr('Forgot password?', 'የይለፍ ቃል ረሱ?')),
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _signIn,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr('Sign in', 'ይግቡ')),
          ),
        ] else ...[
          Text(
            context.tr('We will send a one-time code to the phone on your account.',
                'በመለያዎ ላይ ወዳለው ስልክ የአንድ ጊዜ ኮድ እንልካለን።'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            enabled: !_codeSent,
            decoration: InputDecoration(labelText: context.tr('Phone number', 'ስልክ ቁጥር'), hintText: '0911 234 567'),
          ),
          const SizedBox(height: 10),
          if (!_codeSent) ...[
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('SMS'),
                selected: _channel == 'sms',
                onSelected: (_) => setState(() => _channel = 'sms'),
              ),
              ChoiceChip(
                label: const Text('Telegram'),
                selected: _channel == 'telegram',
                onSelected: (_) => setState(() => _channel = 'telegram'),
              ),
            ]),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(context.tr('Send code', 'ኮድ ላክ')),
            ),
          ] else ...[
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              onSubmitted: (_) => _verifyCode(),
              decoration: InputDecoration(labelText: context.tr('6-digit code', 'ባለ 6 አሃዝ ኮድ')),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _verifyCode,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.tr('Sign in', 'ይግቡ')),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _codeSent = false),
              child: Text(context.tr('Use a different number', 'ሌላ ቁጥር ይጠቀሙ')),
            ),
          ],
        ],
        _ErrorLine(_error),
        const _OrDivider(),
        _GoogleButton(onPressed: _busy ? null : () => _run(AuthService.signInWithGoogle)),
        if (AppConfig.phoneCodes) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _phoneMode = !_phoneMode;
                      _error = null;
                    }),
            icon: Icon(_phoneMode ? Icons.mail_outline : Icons.sms_outlined),
            label: Text(_phoneMode
                ? context.tr('Use email and password', 'በኢሜይል እና የይለፍ ቃል')
                : context.tr('Sign in with a phone code', 'በስልክ ኮድ ይግቡ')),
          ),
        ],
      ],
      below: [
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () => context.go('/signup${_carry(widget.next, widget.role)}'),
            child: Text(context.tr('New to A Studio? Create an account', 'አዲስ ነዎት? መለያ ይፍጠሩ')),
          ),
        ),
      ],
    );
  }
}

// ===================================================================== sign up

class SignUpScreen extends StatefulWidget {
  final String next;
  final String role;
  const SignUpScreen({super.key, this.next = '', this.role = 'client'});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late String _role = widget.role == 'artist' ? 'artist' : 'client';
  bool _terms = false;
  bool _storage = false;
  bool _marketing = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _problem() {
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_name.text.trim().length < 2) return context.tr('Enter your full name.', 'ሙሉ ስምዎን ያስገቡ።');
    if (!isEmail(_email.text)) {
      return context.tr('Enter a valid email. We send booking updates there.', 'ትክክለኛ ኢሜይል ያስገቡ።');
    }
    if (digits.length < 9) {
      return context.tr('Enter your phone number so artists and clients can reach you.', 'ስልክ ቁጥርዎን ያስገቡ።');
    }
    if (_password.text.length < 8) {
      return context.tr('Use a password with at least 8 characters.', 'ቢያንስ 8 ፊደል ያለው የይለፍ ቃል ይጠቀሙ።');
    }
    if (!_terms || !_storage) {
      return context.tr('Please accept the Terms, Privacy Policy and data storage to continue.',
          'ለመቀጠል የአገልግሎት ውሉን፣ የግላዊነት ፖሊሲውን እና የመረጃ ማከማቻውን ይቀበሉ።');
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final phone = normalizeEthiopianPhone(_phone.text) ?? _phone.text.trim();
    final target = _role == 'artist' ? '/desk/setup' : (widget.next.isEmpty ? '/' : widget.next);
    final session = Session.instance;
    session.hold(true);
    try {
      await AuthService.signUp(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        phone: phone,
        role: _role,
        marketing: _marketing,
        lang: _lang(),
      );
      if (mounted) context.go(target);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AuthService.friendlyError(e);
        });
      }
    } finally {
      session.hold(false);
    }
  }

  Future<void> _google() async {
    if (!_terms || !_storage) {
      setState(() => _error = context.tr('Please tick the first two boxes before continuing with Google.',
          'በGoogle ከመቀጠልዎ በፊት የመጀመሪያዎቹን ሁለት ሳጥኖች ምልክት ያድርጉ።'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // New Google accounts land on /welcome to add a phone number.
      await AuthService.signInWithGoogle();
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
    final artist = _role == 'artist';
    return _AuthFrame(
      kicker: artist ? context.tr('For artists', 'ለባለሙያዎች') : context.tr('Join A Studio', 'ኤ ስቱዲዮን ይቀላቀሉ'),
      title: artist
          ? context.tr('Open your studio', 'ስቱዲዮዎን ይክፈቱ')
          : context.tr("Let's get you ready", 'እንዘጋጅ'),
      subtitle: artist
          ? context.tr('Your page, your link, your bookings. Free to start.',
              'የራስዎ ገጽ፣ የራስዎ ሊንክ፣ የራስዎ ቀጠሮዎች። በነጻ ይጀምሩ።')
          : context.tr('Book Addis Ababa\'s best makeup, nails and hair artists.',
              'የአዲስ አበባን ምርጥ የሜካፕ፣ የጥፍር እና የፀጉር ባለሙያዎች ያግኙ።'),
      fields: [
        _RolePicker(role: _role, onChanged: (v) => setState(() => _role = v)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: artist ? context.tr('Your full name', 'ሙሉ ስምዎ') : context.tr('Full name', 'ሙሉ ስም'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: context.tr('Email (required)', 'ኢሜይል (ግዴታ)'),
            helperText: context.tr('Booking confirmations and receipts come here.', 'የቀጠሮ ማረጋገጫዎች እዚህ ይላካሉ።'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(
            labelText: context.tr('Phone number', 'ስልክ ቁጥር'),
            hintText: '0911 234 567',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: context.tr('Password (8+ characters)', 'የይለፍ ቃል (8+ ፊደላት)'),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Consents(
          terms: _terms,
          storage: _storage,
          marketing: _marketing,
          onTerms: (v) => setState(() => _terms = v),
          onStorage: (v) => setState(() => _storage = v),
          onMarketing: (v) => setState(() => _marketing = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(artist ? context.tr('Create my studio account', 'የስቱዲዮ መለያዬን ፍጠር') : context.tr('Create account', 'መለያ ፍጠር')),
        ),
        _ErrorLine(_error),
        const _OrDivider(),
        _GoogleButton(onPressed: _busy ? null : _google),
      ],
      below: [
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () => context.go('/signin${_carry(widget.next, _role == 'artist' ? 'artist' : '')}'),
            child: Text(context.tr('Already have an account? Sign in', 'መለያ አለዎት? ይግቡ')),
          ),
        ),
      ],
    );
  }
}

// ===================================================================== welcome

/// For accounts that exist in Firebase Auth but have no profile yet
/// (Google sign-in, or a sign-up interrupted halfway).
class WelcomeScreen extends StatefulWidget {
  final String next;
  final String role;
  const WelcomeScreen({super.key, this.next = '', this.role = ''});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late final _name = TextEditingController(text: _user?.displayName ?? '');
  late final _email = TextEditingController(text: _user?.email ?? '');
  late final _phone = TextEditingController(text: _user?.phoneNumber ?? '');
  late String _role = widget.role == 'artist' ? 'artist' : 'client';
  bool _terms = false;
  bool _storage = false;
  bool _marketing = false;
  bool _busy = false;
  String? _error;

  bool get _emailLocked => (_user?.email ?? '').isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = _user;
    if (user == null) return;
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    String? problem;
    if (_name.text.trim().length < 2) {
      problem = context.tr('Enter your full name.', 'ሙሉ ስምዎን ያስገቡ።');
    } else if (!isEmail(_email.text)) {
      problem = context.tr('Enter a valid email.', 'ትክክለኛ ኢሜይል ያስገቡ።');
    } else if (digits.length < 9) {
      problem = context.tr('Enter your phone number.', 'ስልክ ቁጥርዎን ያስገቡ።');
    } else if (!_terms || !_storage) {
      problem = context.tr('Please accept the Terms, Privacy Policy and data storage to continue.',
          'ለመቀጠል የአገልግሎት ውሉን እና የግላዊነት ፖሊሲውን ይቀበሉ።');
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final target = _role == 'artist' ? '/desk/setup' : (widget.next.isEmpty ? '/' : widget.next);
    final session = Session.instance;
    session.hold(true);
    try {
      await AuthService.createProfile(
        uid: user.uid,
        name: _name.text,
        email: _email.text,
        phone: normalizeEthiopianPhone(_phone.text) ?? _phone.text.trim(),
        role: _role,
        marketing: _marketing,
        photoUrl: user.photoURL ?? '',
        lang: _lang(),
      );
      if (!_emailLocked) {
        try {
          await user.verifyBeforeUpdateEmail(_email.text.trim());
        } catch (_) {}
      }
      if (mounted) context.go(target);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AuthService.friendlyError(e);
        });
      }
    } finally {
      session.hold(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      kicker: context.tr('Almost there', 'ሊጨርሱ ነው'),
      title: context.tr('A few details', 'ጥቂት ዝርዝሮች'),
      subtitle: context.tr('Artists and clients need a way to reach each other about bookings.',
          'ባለሙያዎች እና ደንበኞች ስለ ቀጠሮ የሚገናኙበት መንገድ ያስፈልጋቸዋል።'),
      fields: [
        _RolePicker(role: _role, onChanged: (v) => setState(() => _role = v)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: context.tr('Full name', 'ሙሉ ስም')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          readOnly: _emailLocked,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: context.tr('Email (required)', 'ኢሜይል (ግዴታ)')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: context.tr('Phone number', 'ስልክ ቁጥር'), hintText: '0911 234 567'),
        ),
        const SizedBox(height: 10),
        _Consents(
          terms: _terms,
          storage: _storage,
          marketing: _marketing,
          onTerms: (v) => setState(() => _terms = v),
          onStorage: (v) => setState(() => _storage = v),
          onMarketing: (v) => setState(() => _marketing = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(context.tr('Continue', 'ቀጥል')),
        ),
        _ErrorLine(_error),
      ],
      below: [
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () async {
              await Session.instance.signOut();
              if (context.mounted) context.go('/');
            },
            child: Text(context.tr('Not you? Sign out', 'እርስዎ አይደሉም? ይውጡ')),
          ),
        ),
      ],
    );
  }
}
