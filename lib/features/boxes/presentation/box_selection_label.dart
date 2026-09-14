import '../../../core/database/app_database.dart';
import '../../../l10n/generated/app_localizations.dart';

String boxSelectionLabel(AppLocalizations localizations, Box box) {
  final fallbackLabel = localizations.boxLabel(box.id);
  final name = box.name?.trim();

  if (name == null || name.isEmpty) {
    return fallbackLabel;
  }

  return '$name · $fallbackLabel';
}
