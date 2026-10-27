import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The brand's "ruled monogram" mark (design variant 1B): an ink border,
/// a red ledger-line rule, and the "HS" monogram set bottom-left — ink on
/// ground, the quietest of the brand's three marks and the closest to the
/// app's own chrome.
///
/// Proportions are ratios of [size], taken directly from the brand design
/// (a 168px reference cell): border 4/168, rule height 6/168, rule offset
/// from the inner bottom edge 44/168, padding 16/168 horizontal and
/// 14/168 vertical, monogram font-size 74/168. This same widget is also
/// the source rendered by `tool/icon_gen` to produce the app icon and
/// splash image files — change the design here and regenerate both.
class RuledMonogram extends StatelessWidget {
  const RuledMonogram({
    super.key,
    required this.size,
    this.backgroundColor,
    this.fontFamily,
  });

  final double size;

  /// Fill behind the mark. Pass null for a transparent background (used
  /// for the Android adaptive-icon foreground layer).
  final Color? backgroundColor;

  /// Left null in the running app (falls back to the platform default —
  /// deliberately not Archivo, so the splash mark never depends on
  /// google_fonts' network fetch completing first). tool/icon_gen passes
  /// a locally-loaded font here instead, since flutter_test substitutes a
  /// placeholder glyph-less font unless one is explicitly loaded.
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RuledMonogramPainter(
        backgroundColor: backgroundColor,
        fontFamily: fontFamily,
      ),
    );
  }
}

class _RuledMonogramPainter extends CustomPainter {
  const _RuledMonogramPainter({required this.backgroundColor, this.fontFamily});

  final Color? backgroundColor;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final borderWidth = s * (4 / 168);
    final ruleHeight = s * (6 / 168);
    final ruleBottomOffset = s * (44 / 168);
    final hPad = s * (16 / 168);
    final bottomPad = s * (14 / 168);
    final fontSize = s * (74 / 168);

    final rect = Offset.zero & size;
    final bg = backgroundColor;
    if (bg != null) {
      canvas.drawRect(rect, Paint()..color = bg);
    }

    canvas.drawRect(
      rect.deflate(borderWidth / 2),
      Paint()
        ..color = AppColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    final innerBottom = s - borderWidth;
    final innerLeft = borderWidth;
    final innerRight = s - borderWidth;
    final ruleBottom = innerBottom - ruleBottomOffset;
    canvas.drawRect(
      Rect.fromLTRB(innerLeft, ruleBottom - ruleHeight, innerRight, ruleBottom),
      Paint()..color = AppColors.accent,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'HS',
        style: TextStyle(
          color: AppColors.text,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -fontSize * 0.05,
          height: 0.78,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(innerLeft + hPad, innerBottom - bottomPad - textPainter.height),
    );
  }

  @override
  bool shouldRepaint(covariant _RuledMonogramPainter oldDelegate) => false;
}
