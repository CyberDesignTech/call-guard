import '../../l10n/app_strings.dart';

String localizedValue(AppStrings strings, String value) {
  if (value.startsWith('@')) return strings.call(value.substring(1));
  if (AppStrings.keys.contains(value)) return strings.call(value);
  return value;
}
