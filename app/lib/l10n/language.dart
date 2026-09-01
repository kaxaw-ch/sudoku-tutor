/// Stable language identifiers shared by persistence and presentation layers.
library;

/// The two languages currently shipped by the app.
abstract final class AppLanguages {
  /// Simplified Chinese (default).
  static const String chinese = 'zh';

  /// English.
  static const String english = 'en';

  /// Sanitizes persisted or imported values so an unknown value never changes
  /// the app away from its Chinese default.
  static String normalize(String? value) =>
      value == english ? english : chinese;
}
