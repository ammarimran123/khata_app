import 'package:flutter/material.dart';

/// Colors lifted directly from the design system's CSS custom properties.
class AppColors {
  const AppColors._();

  static const Color bg = Color(0xFFF3F2F2);
  static const Color surface = Color(0xFFEAE9E9);
  static const Color text = Color(0xFF201E1D);
  static const Color divider = Color(0x66201E1D); // 40% mix over transparent

  static const Color accent = Color(0xFFEC3013);
  static const Color accent2 = Color(0xFFE15B47);

  // Neutral ramp.
  static const Color neutral100 = Color(0xFFF8F4F4);
  static const Color neutral200 = Color(0xFFEAE7E7);
  static const Color neutral300 = Color(0xFFD7D3D3);
  static const Color neutral400 = Color(0xFFBAB6B6);
  static const Color neutral500 = Color(0xFF9B9797);
  static const Color neutral600 = Color(0xFF7D7979);
  static const Color neutral700 = Color(0xFF605D5D);
  static const Color neutral800 = Color(0xFF444141);
  static const Color neutral900 = Color(0xFF2D2B2B);

  // Accent ramp (used for tags, receivable/payable emphasis).
  static const Color accent100 = Color(0xFFFFF2EF);
  static const Color accent200 = Color(0xFFFFE0D9);
  static const Color accent300 = Color(0xFFFFC4B8);
  static const Color accent600 = Color(0xFFDD2B0F);
  static const Color accent700 = Color(0xFFAE1800);
  static const Color accent800 = Color(0xFF7C1405);
  static const Color accent900 = Color(0xFF4D170E);

  /// Positive/receivable/credit amounts use plain text color; negative/
  /// payable/debit amounts use the accent. Never treat sign as profit/loss —
  /// this is purely the client-ledger presentation color.
  static Color ledgerAmountColor(num balance) {
    if (balance < 0) return accent700;
    return text;
  }
}
