import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// "A STUDIO" masthead in bold Bodoni Moda (the only place Bodoni is used,
/// with the "A." mark below).
class Wordmark extends StatelessWidget {
  final double size;
  final Color? color;
  const Wordmark({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Text(
      'A STUDIO',
      style: TextStyle(
        fontFamily: kWordmark,
        fontFamilyFallback: kSerifFallback,
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: size * 0.16,
        color: c,
        height: 1,
      ),
    );
  }
}

/// The "A." app mark: italic A with a champagne dot.
class Monogram extends StatelessWidget {
  final double size;
  const Monogram({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('A',
              style: displayStyle(size * 0.62,
                  color: AppColors.milk, style: FontStyle.italic, height: 1, family: 'Bodoni')),
          Container(
            width: size * 0.1,
            height: size * 0.1,
            margin: EdgeInsets.only(bottom: size * 0.16, left: 1),
            decoration: const BoxDecoration(
                color: AppColors.champagne, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

/// The champagne tibeb border: diamonds and crosses between two rules,
/// after the woven edge of a habesha kemis.
class TibebBorder extends StatelessWidget {
  final double height;
  final Color color;
  const TibebBorder({super.key, this.height = 26, this.color = AppColors.champagne});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TibebPainter(color)),
    );
  }
}

class _TibebPainter extends CustomPainter {
  final Color color;
  _TibebPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    canvas.drawLine(Offset(0, 0.5), Offset(size.width, 0.5), line);
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), line);
    final cy = size.height / 2;
    final r = size.height * 0.28;
    const step = 28.0;
    var i = 0;
    for (var x = 10.0; x < size.width - 6; x += step) {
      if (i.isEven) {
        final path = Path()
          ..moveTo(x, cy - r)
          ..lineTo(x + r, cy)
          ..lineTo(x, cy + r)
          ..lineTo(x - r, cy)
          ..close();
        canvas.drawPath(path, line);
        final inner = Path()
          ..moveTo(x, cy - r * 0.4)
          ..lineTo(x + r * 0.4, cy)
          ..lineTo(x, cy + r * 0.4)
          ..lineTo(x - r * 0.4, cy)
          ..close();
        canvas.drawPath(inner, fill);
      } else {
        canvas.drawLine(Offset(x - r * 0.55, cy), Offset(x + r * 0.55, cy), line);
        canvas.drawLine(Offset(x, cy - r * 0.55), Offset(x, cy + r * 0.55), line);
      }
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _TibebPainter old) => old.color != color;
}
