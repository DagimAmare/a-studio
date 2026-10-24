import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/tr.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// Centered, width-capped page body.
class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? kicker;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.kicker, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(kicker!.toUpperCase(),
                        style: labelCaps(color: t.colorScheme.onSurfaceVariant)),
                  ),
                Text(title, style: t.textTheme.headlineMedium),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Loading extends StatelessWidget {
  final double size;
  const Loading({super.key, this.size = 28});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: t.textTheme.titleLarge),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!,
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  const ErrorView(this.message, {super.key});
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: context.tr('Something went wrong', 'የሆነ ችግር ተፈጥሯል'),
        body: message,
      );
}

/// Network image with a soft placeholder. Same-origin media needs no CORS;
/// other hosts (e.g. Google photos) fall back to an <img> element.
class NetImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? radius;
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.radius});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.oat,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.latte),
    );
    if (url.isEmpty) {
      return radius == null ? placeholder : ClipRRect(borderRadius: radius!, child: placeholder);
    }
    final img = Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (c, child, progress) => progress == null ? child : placeholder,
      errorBuilder: (c, e, s) => placeholder,
    );
    return radius == null ? img : ClipRRect(borderRadius: radius!, child: img);
  }
}

class Avatar extends StatelessWidget {
  final String url;
  final String name;
  final double size;
  const Avatar({super.key, required this.url, required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'A'
        : name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? Container(
                color: AppColors.petal,
                alignment: Alignment.center,
                child: Text(initials,
                    style: displayStyle(size * 0.38, color: AppColors.cocoa)),
              )
            : NetImage(url, width: size, height: size),
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;
  const RatingStars(this.rating, {super.key, this.size = 15, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.champagne;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final v = rating - i;
        final icon = v >= 0.75
            ? Icons.star_rounded
            : (v >= 0.25 ? Icons.star_half_rounded : Icons.star_outline_rounded);
        return Icon(icon, size: size, color: c);
      }),
    );
  }
}

class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 30});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (i) => IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(i + 1),
            icon: Icon(i < value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size, color: AppColors.champagne),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;
  const Pill(this.text,
      {super.key, this.background = AppColors.petal, this.foreground = AppColors.cocoa, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: foreground), const SizedBox(width: 4)],
            Text(text,
                style: TextStyle(
                    fontFamily: 'DMSans',
                    fontFamilyFallback: kSansFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: foreground)),
          ],
        ),
      );
}

/// Opens WhatsApp, Telegram, mail or a web page.
Future<void> openExternal(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
}

/// Same tab (legal pages live on the same site).
Future<void> openSameTab(String path) async {
  await launchUrl(Uri.parse(path), webOnlyWindowName: '_self');
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> copyText(BuildContext context, String text, {String? done}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, done ?? context.tr('Copied', 'ተቀድቷል'));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, String? body, String? confirm, bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('Cancel', 'ይቅር'))),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.rouge) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm ?? c.tr('Confirm', 'አረጋግጥ')),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> textPrompt(BuildContext context,
    {required String title,
    String? hint,
    String initial = '',
    int maxLines = 3,
    bool required = false,
    String? confirm}) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(c.tr('Cancel', 'ይቅር'))),
        FilledButton(
          onPressed: () {
            if (required && ctrl.text.trim().isEmpty) return;
            Navigator.pop(c, ctrl.text.trim());
          },
          child: Text(confirm ?? c.tr('Save', 'አስቀምጥ')),
        ),
      ],
    ),
  );
  return result;
}

/// A labelled dropdown that avoids the deprecated form-field `value` API.
class SelectField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  const SelectField({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: items.any((i) => i.$1 == value) ? value : null,
          hint: Text(context.tr('Choose', 'ይምረጡ')),
          items: items
              .map((i) => DropdownMenuItem<T>(value: i.$1, child: Text(i.$2, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Wraps long-running actions with a spinner and friendly errors.
class Busy {
  static Future<T?> run<T>(BuildContext context, Future<T> Function() action,
      {String? success, String Function(Object e)? error}) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Loading(size: 34)),
    );
    try {
      final r = await action();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (success != null) toast(context, success);
      }
      return r;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        toast(context, error != null ? error(e) : _friendly(e));
      }
      return null;
    }
  }

  static String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied')) {
      return 'You do not have permission to do that.';
    }
    if (s.contains('unavailable') || s.contains('network')) {
      return 'No connection. Check your internet and try again.';
    }
    if (s.contains('TimeoutException')) return 'That took too long. Try again.';
    return s.replaceFirst('Exception: ', '');
  }
}
