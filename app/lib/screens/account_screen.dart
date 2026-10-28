import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/validators.dart';
import '../l10n/tr.dart';
import '../platform/web_bridge.dart' as bridge;
import '../services/account_service.dart';
import '../services/activity.dart';
import '../services/auth_service.dart';
import '../services/db.dart';
import '../services/media_service.dart';
import '../services/push_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';
import '../widgets/phone_verify.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) => SignedInGate(builder: (_) => const _Account());
}

class _Account extends StatefulWidget {
  const _Account();
  @override
  State<_Account> createState() => _AccountState();
}

const List<String> _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class _AccountState extends State<_Account> {
  final Session s = Session.instance;
  late final _name = TextEditingController(text: s.profile?.name ?? '');
  late final _phone = TextEditingController(text: s.profile?.phone ?? '');
  late int? _bMonth = _parseBirthday(s.profile?.birthday ?? '').$1;
  late int? _bDay = _parseBirthday(s.profile?.birthday ?? '').$2;
  bool _uploading = false;

  static (int?, int?) _parseBirthday(String v) {
    final p = v.split('-');
    if (p.length != 2) return (null, null);
    return (int.tryParse(p[0]), int.tryParse(p[1]));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _update(Map<String, dynamic> data, {String? done}) async {
    await Busy.run(context, () async {
      await Db.users.doc(s.uid).set(data, SetOptions(merge: true)).timeout(Db.timeout);
      Activity.log('profile_update', targetType: 'user', targetId: s.uid, summary: data.keys.join(', '));
    }, success: done ?? context.tr('Saved', 'ተቀምጧል'));
  }

  Future<void> _saveProfile() async {
    final name = _name.text.trim();
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.length < 2) {
      toast(context, context.tr('Enter your name.', 'ስምዎን ያስገቡ።'));
      return;
    }
    if (digits.length < 9) {
      toast(context, context.tr('Enter your phone number.', 'ስልክ ቁጥርዎን ያስገቡ።'));
      return;
    }
    final phone = normalizeEthiopianPhone(_phone.text) ?? _phone.text.trim();
    final phoneChanged = phone != (s.profile?.phone ?? '');
    await _update({
      'name': name,
      'phone': phone,
      if (phoneChanged) 'phoneVerified': false,
      'birthday': (_bMonth != null && _bDay != null)
          ? '${_bMonth.toString().padLeft(2, '0')}-${_bDay.toString().padLeft(2, '0')}'
          : '',
    });
  }

  Future<void> _uploadPhoto() async {
    try {
      final picked = await MediaService.pickImages(multiple: false);
      if (picked.isEmpty || !mounted) return;
      setState(() => _uploading = true);
      final old = s.profile?.photoUrl ?? '';
      final up = await MediaService.upload(picked.first);
      await Db.users.doc(s.uid).set({'photoUrl': up.url}, SetOptions(merge: true)).timeout(Db.timeout);
      if (old.isNotEmpty && old.contains('/media/')) MediaService.delete(old);
      if (mounted) toast(context, context.tr('Photo updated', 'ፎቶ ተቀይሯል'));
    } catch (e) {
      if (mounted) toast(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _export() async {
    final json = await Busy.run(context, AccountService.exportData);
    if (json == null || !mounted) return;
    bridge.downloadText('a-studio-my-data.json', json);
    toast(context, context.tr('Your data file is downloading', 'የውሂብዎ ፋይል እየወረደ ነው'));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteDialog(),
    );
    if (confirmed == null || !mounted) return;
    final ok = await Busy.run<bool>(
      context,
      () async {
        await AccountService.deleteEverything(password: confirmed.isEmpty ? null : confirmed);
        return true;
      },
      error: (e) => AuthService.friendlyError(e),
    );
    if (ok == true && mounted) {
      context.go('/');
      toast(context, context.tr('Your account and data have been deleted.', 'መለያዎ እና ውሂብዎ ተሰርዘዋል።'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final am = context.isAm;
    final p = s.profile;
    final user = s.user;
    final emailVerified = user?.emailVerified ?? false;
    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        PageBody(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(context.tr('Account', 'መለያ')),
              if (p?.suspended ?? false)
                Card(
                  color: AppColors.honey.withValues(alpha: 0.12),
                  child: ListTile(
                    leading: const Icon(Icons.pause_circle_outline, color: AppColors.honey),
                    title: Text(context.tr('Your account is paused', 'መለያዎ ቆሟል')),
                    subtitle: Text(context.tr('Write to ${AppConfig.supportEmail} to sort it out.',
                        'ለመፍታት ወደ ${AppConfig.supportEmail} ይጻፉ።')),
                  ),
                ),
              // ---------------------------------------------------- profile
              _Section(
                title: context.tr('Your details', 'የእርስዎ ዝርዝሮች'),
                children: [
                  Row(children: [
                    Avatar(url: p?.photoUrl ?? '', name: s.displayName, size: 64),
                    const SizedBox(width: 14),
                    OutlinedButton(
                      onPressed: _uploading ? null : _uploadPhoto,
                      child: _uploading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(context.tr('Change photo', 'ፎቶ ቀይር')),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: context.tr('Full name', 'ሙሉ ስም')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: context.tr('Phone', 'ስልክ'),
                      suffixIcon: (p?.phoneVerified ?? false)
                          ? const Tooltip(message: 'Verified', child: Icon(Icons.verified, color: AppColors.sage))
                          : null,
                    ),
                  ),
                  if (AppConfig.phoneCodes && !(p?.phoneVerified ?? false))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          final ok = await showPhoneVerifyDialog(context, p?.phone ?? '');
                          if (ok && context.mounted) toast(context, context.tr('Phone verified', 'ስልክ ተረጋግጧል'));
                        },
                        child: Text(context.tr('Verify my phone', 'ስልኬን አረጋግጥ')),
                      ),
                    ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: InputDecoration(labelText: context.tr('Email', 'ኢሜይል')),
                    child: Row(children: [
                      Expanded(child: Text(user?.email ?? p?.email ?? '')),
                      if (emailVerified)
                        Pill(context.tr('Verified', 'የተረጋገጠ'), icon: Icons.verified_outlined, background: AppColors.oat)
                      else
                        TextButton(
                          onPressed: () => Busy.run(context, AuthService.resendVerification,
                              success: context.tr('Check your inbox for the link', 'ሊንኩን በኢሜይልዎ ይመልከቱ')),
                          child: Text(context.tr('Send link', 'ሊንክ ላክ')),
                        ),
                    ]),
                  ),
                  if (!emailVerified)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          final ok = await Busy.run(context, AuthService.refreshEmailVerified);
                          if (!context.mounted) return;
                          toast(
                              context,
                              ok == true
                                  ? context.tr('Email verified', 'ኢሜይል ተረጋግጧል')
                                  : context.tr('Not confirmed yet. Open the link in the email first.',
                                      'ገና አልተረጋገጠም። መጀመሪያ በኢሜይሉ ያለውን ሊንክ ይክፈቱ።'));
                          if (ok == true) setState(() {});
                        },
                        child: Text(context.tr("I've clicked the link", 'ሊንኩን ከፍቻለሁ')),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(context.tr('Birthday (for a greeting and an offer, if you opt in)', 'የልደት ቀን (ለሰላምታ እና ቅናሽ)'),
                      style: t.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: SelectField<int>(
                        label: context.tr('Month', 'ወር'),
                        value: _bMonth,
                        items: [for (var m = 1; m <= 12; m++) (m, _monthsEn[m - 1])],
                        onChanged: (v) => setState(() => _bMonth = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectField<int>(
                        label: context.tr('Day', 'ቀን'),
                        value: _bDay,
                        items: [for (var d = 1; d <= 31; d++) (d, '$d')],
                        onChanged: (v) => setState(() => _bDay = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(onPressed: _saveProfile, child: Text(context.tr('Save', 'አስቀምጥ'))),
                  ),
                ],
              ),
              // ---------------------------------------------------- language and notifications
              _Section(
                title: context.tr('Language and notifications', 'ቋንቋ እና ማሳወቂያዎች'),
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'am', label: Text('አማርኛ')),
                    ],
                    selected: {am ? 'am' : 'en'},
                    onSelectionChanged: (v) {
                      LocaleController.instance.set(v.first);
                      Db.users.doc(s.uid).set({'lang': v.first}, SetOptions(merge: true)).catchError((_) {});
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: p?.emailNotifs ?? true,
                    onChanged: (v) => _update({'prefs': {'email': v}}),
                    title: Text(context.tr('Email me booking updates', 'የቀጠሮ ዝመናዎችን በኢሜይል ላኩልኝ')),
                    subtitle: Text(context.tr('Receipts and confirmations always come by email.', 'ደረሰኞች እና ማረጋገጫዎች ሁልጊዜ በኢሜይል ይመጣሉ።')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: p?.marketing ?? false,
                    onChanged: (v) => _update({'prefs': {'marketing': v}}),
                    title: Text(context.tr('Holiday, wedding-season and birthday messages', 'የበዓል፣ የሠርግ ወቅት እና የልደት መልዕክቶች')),
                    subtitle: Text(context.tr('At most two a week. Turn off any time.', 'በሳምንት ቢበዛ ሁለት። በማንኛውም ጊዜ ያጥፉ።')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: p?.tips ?? true,
                    onChanged: (v) => _update({'prefs': {'tips': v}}),
                    title: Text(context.tr('Getting-started tips by email', 'የመጀመሪያ ምክሮች በኢሜይል')),
                    subtitle: Text(context.tr(
                        'A few emails in your first week: opening a studio, The Vanity and how bookings work.',
                        'በመጀመሪያው ሳምንትዎ ጥቂት ኢሜይሎች፡ ስቱዲዮ መክፈት፣ የውበት ሱቁ እና ቀጠሮ እንዴት እንደሚሠራ።')),
                  ),
                  if (AppConfig.pushConfigured)
                    ValueListenableBuilder<bool>(
                      valueListenable: PushService.enabled,
                      builder: (context, on, _) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(on ? Icons.notifications_active : Icons.notifications_off_outlined),
                        title: Text(on
                            ? context.tr('Alerts are on for this device', 'በዚህ መሣሪያ ማሳወቂያዎች በርተዋል')
                            : context.tr('Alerts are off for this device', 'በዚህ መሣሪያ ማሳወቂያዎች ጠፍተዋል')),
                        trailing: on
                            ? null
                            : OutlinedButton(
                                onPressed: () async {
                                  final ok = await PushService.enable(s.uid);
                                  if (!context.mounted) return;
                                  toast(
                                      context,
                                      ok
                                          ? context.tr('Alerts are on', 'ማሳወቂያዎች በርተዋል')
                                          : context.tr('Your browser blocked alerts. Allow them in its site settings.',
                                              'አሳሽዎ ማሳወቂያዎችን ከልክሏል።'));
                                },
                                child: Text(context.tr('Turn on', 'አብራ')),
                              ),
                      ),
                    ),
                ],
              ),
              // ---------------------------------------------------- studio and backstage
              _Section(
                title: context.tr('Your studio', 'ስቱዲዮዎ'),
                children: [
                  if (s.studio != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(s.studio!.name),
                      subtitle: Text(AppConfig.studioLink(s.studio!.handle).replaceFirst('https://', '')),
                      trailing: FilledButton(
                        onPressed: () => context.go('/desk'),
                        child: Text(context.tr('Studio Desk', 'የስቱዲዮ ዴስክ')),
                      ),
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.brush_outlined),
                      title: Text(context.tr('Are you a makeup, nails or hair artist?', 'የሜካፕ፣ የጥፍር ወይም የፀጉር ባለሙያ ነዎት?')),
                      subtitle: Text(context.tr('Get your own page, link and bookings.', 'የራስዎን ገጽ፣ ሊንክ እና ቀጠሮዎች ያግኙ።')),
                      trailing: OutlinedButton(
                        onPressed: () => context.go('/desk/setup'),
                        child: Text(context.tr('Open a studio', 'ስቱዲዮ ክፈት')),
                      ),
                    ),
                  if (s.isAdmin)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(context.tr('Backstage', 'የአስተዳደር ገጽ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/backstage'),
                    ),
                ],
              ),
              // ---------------------------------------------------- privacy
              _Section(
                title: context.tr('Privacy and your data', 'ግላዊነት እና ውሂብዎ'),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(context.tr('Terms of Use', 'የአገልግሎት ውል')),
                    onTap: () => openSameTab(AppConfig.termsPath),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(context.tr('Privacy Policy', 'የግላዊነት ፖሊሲ')),
                    onTap: () => openSameTab(AppConfig.privacyPath),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_outlined),
                    title: Text(context.tr('Download my data', 'ውሂቤን አውርድ')),
                    subtitle: Text(context.tr('A file with your profile, bookings, reviews and listings.',
                        'መገለጫዎን፣ ቀጠሮዎችን፣ ግምገማዎችን እና እቃዎችን የያዘ ፋይል።')),
                    onTap: _export,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever_outlined, color: AppColors.rouge),
                    title: Text(context.tr('Delete my account', 'መለያዬን ሰርዝ'), style: const TextStyle(color: AppColors.rouge)),
                    subtitle: Text(context.tr('Removes your profile, studio, photos and listings for good.',
                        'መገለጫዎን፣ ስቱዲዮዎን፣ ፎቶዎችን እና እቃዎችን በቋሚነት ያስወግዳል።')),
                    onTap: _delete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await s.signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout),
                label: Text(context.tr('Sign out', 'ውጣ')),
              ),
              const SizedBox(height: 24),
              Center(child: Text('A Studio ${AppConfig.buildLabel}', style: labelCaps(size: 11, spacing: 1.2))),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => openExternal('mailto:${AppConfig.supportEmail}'),
                  child: Text(AppConfig.supportEmail),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...children,
            ]),
          ),
        ),
      );
}

/// Returns the password ('' for Google accounts) once the person has typed
/// DELETE; null when cancelled.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();
  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final bool _usesPassword = AuthService.usesPassword;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _confirm.text.trim().toUpperCase() == 'DELETE' && (!_usesPassword || _password.text.isNotEmpty);
    return AlertDialog(
      title: Text(context.tr('Delete your account?', 'መለያዎን ይሰርዙ?')),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr(
                'This permanently deletes your profile, your studio page and link, your portfolio photos and videos, your listings and your notifications. Past bookings and reviews stay for the other person\'s records, with your name removed. This cannot be undone.',
                'ይህ መገለጫዎን፣ የስቱዲዮ ገጽዎን እና ሊንክዎን፣ የሥራ ፎቶዎችዎን እና ቪዲዮዎችዎን፣ እቃዎችዎን እና ማሳወቂያዎችዎን በቋሚነት ይሰርዛል። ያለፉ ቀጠሮዎች እና ግምገማዎች ለሌላኛው ወገን መዝገብ ስምዎ ተወግዶ ይቆያሉ። ይህ ሊቀለበስ አይችልም።')),
            const SizedBox(height: 14),
            if (_usesPassword) ...[
              TextField(
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: context.tr('Your password', 'የይለፍ ቃልዎ')),
              ),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(context.tr('Google will ask you to confirm it is you.', 'Google እርስዎ መሆንዎን እንዲያረጋግጡ ይጠይቃል።')),
              ),
            TextField(
              controller: _confirm,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.tr('Type DELETE to confirm', 'ለማረጋገጥ DELETE ብለው ይጻፉ')),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Keep my account', 'መለያዬን አቆይ'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
          onPressed: ready ? () => Navigator.pop(context, _usesPassword ? _password.text : '') : null,
          child: Text(context.tr('Delete forever', 'በቋሚነት ሰርዝ')),
        ),
      ],
    );
  }
}
