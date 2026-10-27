/// Spacing scale from the design system's `--space-*` tokens.
class AppSpacing {
  const AppSpacing._();

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;

  /// The design uses hard 2px rules (not soft dividers) as its primary
  /// structural element — under headings, around stat blocks, above the
  /// bottom nav.
  static const double ruleWidth = 2;
}
