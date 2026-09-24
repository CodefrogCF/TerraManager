import 'package:flutter/widgets.dart';

import '../core/database/enums/animal_archive_reason.dart';
import '../core/database/enums/animal_category.dart';
import '../core/database/enums/box_archive_reason.dart';
import '../core/database/enums/sex.dart';
import '../l10n/app_localizations_context.dart';
import '../l10n/app_localizations_labels.dart';

String sharedText(BuildContext context, String english, String german) =>
    Localizations.localeOf(context).languageCode == 'de' ? german : english;

String? sharedCategoryLabel(BuildContext context, String? raw) {
  if (raw == null) return null;
  for (final category in AnimalCategory.values) {
    if (category.name == raw) return context.l10n.animalCategoryLabel(category);
  }
  return raw;
}

String? sharedSubcategoryLabel(BuildContext context, String? raw) {
  if (raw == null) return null;
  for (final subcategory in AnimalSubcategory.values) {
    if (subcategory.name == raw) {
      return context.l10n.animalSubcategoryLabel(subcategory);
    }
  }
  return raw;
}

String? sharedSexLabel(BuildContext context, String? raw) {
  if (raw == null) return null;
  for (final sex in Sex.values) {
    if (sex.name == raw) return context.l10n.animalSexLabel(sex);
  }
  return raw;
}

String sharedArchiveReasonLabel(
  BuildContext context,
  String raw, {
  required bool box,
}) {
  if (box) {
    for (final reason in BoxArchiveReason.values) {
      if (reason.name == raw) return context.l10n.boxArchiveReasonLabel(reason);
    }
  } else {
    for (final reason in AnimalArchiveReason.values) {
      if (reason.name == raw) {
        return context.l10n.animalArchiveReasonLabel(reason);
      }
    }
  }
  return raw;
}
