import 'package:flutter/widgets.dart';

/// Patterns that indicate a Flutter framework route dump rather than an app
/// screen id (e.g. `_PageBasedMaterialPageRoute<void>(...)`).
final RegExp _technicalRouteNamePattern = RegExp(
  r'MaterialPageRoute|'
  r'PageBasedMaterialPageRoute|'
  r'ModalBottomSheetRoute|'
  r'PopupRoute|'
  r'DialogRoute|'
  r'RawDialogRoute|'
  r'CupertinoPageRoute|'
  r'PageRouteBuilder|'
  r'<void>\(|'
  r'Route<',
  caseSensitive: false,
);

/// Returns a usable screen name for [route], or `null` when auto-track should
/// skip (unnamed / technical dumps). Never falls back to [Route.toString].
String? resolveRouteScreenName(Route<dynamic> route) {
  return sanitizeScreenName(route.settings.name);
}

/// Validates a candidate screen name from route settings or an explicit title.
///
/// Returns the trimmed name, or `null` if empty / technical / unusable.
String? sanitizeScreenName(String? raw) {
  if (raw == null) return null;
  final name = raw.trim();
  if (name.isEmpty) return null;
  if (_isTechnicalScreenName(name)) return null;
  return name;
}

bool _isTechnicalScreenName(String name) {
  if (_technicalRouteNamePattern.hasMatch(name)) {
    return true;
  }
  // Private Flutter route class dumps often start with `_` and include `(` from
  // toString(), e.g. `_PageBasedMaterialPageRoute<void>(...)`.
  if (name.startsWith('_') && name.contains('(')) {
    return true;
  }
  return false;
}
