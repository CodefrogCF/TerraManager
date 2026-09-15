import 'package:flutter/material.dart';

import '../core/database/enums/animal_archive_reason.dart';
import '../core/database/enums/box_archive_reason.dart';
import '../core/database/enums/birth_date_accuracy.dart';
import '../core/database/enums/sex.dart';
import '../features/backup/application/backup_validation_exception.dart';
import '../features/settings/app_accent.dart';
import '../features/settings/app_language.dart';
import '../features/settings/animal_name_order.dart';
import '../features/settings/animal_sort_order.dart';
import '../features/settings/box_sort_order.dart';
import 'generated/app_localizations.dart';

extension AppLocalizationsLabels on AppLocalizations {
  String boxArchiveReasonLabel(BoxArchiveReason reason) {
    return switch (reason) {
      BoxArchiveReason.sold => archiveReasonSold,
      BoxArchiveReason.replaced => boxArchiveReasonReplaced,
      BoxArchiveReason.damaged => boxArchiveReasonDamaged,
      BoxArchiveReason.other => archiveReasonOther,
    };
  }

  String animalArchiveReasonLabel(AnimalArchiveReason reason) {
    return switch (reason) {
      AnimalArchiveReason.sold => archiveReasonSold,
      AnimalArchiveReason.traded => archiveReasonTraded,
      AnimalArchiveReason.deceased => archiveReasonDeceased,
      AnimalArchiveReason.rehomed => archiveReasonRehomed,
      AnimalArchiveReason.other => archiveReasonOther,
    };
  }

  String animalSexLabel(Sex sex) {
    return switch (sex) {
      Sex.male => sexMale,
      Sex.female => sexFemale,
      Sex.unknown => sexUnknown,
      Sex.other => sexOther,
    };
  }

  String birthAccuracyLabel(BirthDateAccuracy accuracy) {
    return switch (accuracy) {
      BirthDateAccuracy.exact => birthDateAccuracyExact,
      BirthDateAccuracy.monthKnown => birthDateAccuracyMonthKnown,
      BirthDateAccuracy.yearKnown => birthDateAccuracyYearKnown,
    };
  }

  String themeModeLabel(ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.system => themeSystem,
      ThemeMode.light => themeLight,
      ThemeMode.dark => themeDark,
    };
  }

  String appAccentLabel(AppAccent accent) {
    return switch (accent) {
      AppAccent.green => accentGreen,
      AppAccent.blue => accentBlue,
      AppAccent.teal => accentTeal,
      AppAccent.orange => accentOrange,
      AppAccent.purple => accentPurple,
      AppAccent.red => accentRed,
    };
  }

  String appLanguageLabel(AppLanguage language) {
    return switch (language) {
      AppLanguage.system => languageSystem,
      AppLanguage.english => languageEnglish,
      AppLanguage.german => languageGerman,
    };
  }

  String animalNameOrderLabel(AnimalNameOrder order) {
    return switch (order) {
      AnimalNameOrder.commonNameFirst => animalNameCommonFirst,
      AnimalNameOrder.latinNameFirst => animalNameLatinFirst,
    };
  }

  String boxSortOrderLabel(BoxSortOrder order) {
    return switch (order) {
      BoxSortOrder.labelAscending => boxSortLabelAscending,
      BoxSortOrder.labelDescending => boxSortLabelDescending,
      BoxSortOrder.nameAscending => boxSortNameAscending,
      BoxSortOrder.nameDescending => boxSortNameDescending,
    };
  }

  String boxSortCriterionMenuLabel(
    BoxSortCriterion criterion, {
    required BoxSortOrder? activeOrder,
  }) {
    final criterionLabel = switch (criterion) {
      BoxSortCriterion.label => boxSortNumberCriterion,
      BoxSortCriterion.name => boxSortNameCriterion,
    };

    if (activeOrder == null) {
      return criterionLabel;
    }

    final directionLabel = switch (activeOrder) {
      BoxSortOrder.labelAscending ||
      BoxSortOrder.nameAscending => sortDirectionAscending,
      BoxSortOrder.labelDescending ||
      BoxSortOrder.nameDescending => sortDirectionDescending,
    };

    return sortCriterionWithDirection(criterionLabel, directionLabel);
  }

  String animalSortOrderLabel(AnimalSortOrder order) {
    return switch (order) {
      AnimalSortOrder.createdOldestFirst => animalSortCreatedOldestFirst,
      AnimalSortOrder.createdNewestFirst => animalSortCreatedNewestFirst,
      AnimalSortOrder.displayNameAscending => animalSortNameAscending,
      AnimalSortOrder.displayNameDescending => animalSortNameDescending,
      AnimalSortOrder.ageOldestFirst => animalSortAgeOldestFirst,
      AnimalSortOrder.ageYoungestFirst => animalSortAgeYoungestFirst,
      AnimalSortOrder.latestFeedingNewestFirst =>
        animalSortLatestFeedingNewestFirst,
      AnimalSortOrder.latestFeedingOldestFirst =>
        animalSortLatestFeedingOldestFirst,
    };
  }

  String animalSortCriterionMenuLabel(
    AnimalSortCriterion criterion, {
    required AnimalSortOrder? activeOrder,
  }) {
    final criterionLabel = switch (criterion) {
      AnimalSortCriterion.created => animalSortCreatedCriterion,
      AnimalSortCriterion.displayName => animalSortDisplayNameCriterion,
      AnimalSortCriterion.age => animalSortAgeCriterion,
      AnimalSortCriterion.latestFeeding => animalSortLatestFeedingCriterion,
    };

    if (activeOrder == null) {
      return criterionLabel;
    }

    final directionLabel = switch (activeOrder) {
      AnimalSortOrder.createdOldestFirst ||
      AnimalSortOrder.ageOldestFirst ||
      AnimalSortOrder.latestFeedingOldestFirst => sortDirectionOldestFirst,
      AnimalSortOrder.createdNewestFirst ||
      AnimalSortOrder.latestFeedingNewestFirst => sortDirectionNewestFirst,
      AnimalSortOrder.displayNameAscending => sortDirectionAscending,
      AnimalSortOrder.displayNameDescending => sortDirectionDescending,
      AnimalSortOrder.ageYoungestFirst => sortDirectionYoungestFirst,
    };

    return sortCriterionWithDirection(criterionLabel, directionLabel);
  }

  String backupValidationErrorLabel(BackupValidationErrorCode code) {
    return switch (code) {
      BackupValidationErrorCode.invalidArchive => backupErrorInvalidArchive,
      BackupValidationErrorCode.unsafeArchivePath =>
        backupErrorUnsafeArchivePath,
      BackupValidationErrorCode.duplicateArchiveEntry =>
        backupErrorDuplicateArchiveEntry,
      BackupValidationErrorCode.missingRequiredFile =>
        backupErrorMissingRequiredFile,
      BackupValidationErrorCode.invalidJson => backupErrorInvalidJson,
      BackupValidationErrorCode.invalidManifest => backupErrorInvalidManifest,
      BackupValidationErrorCode.unsupportedBackupFormat =>
        backupErrorUnsupportedBackupFormat,
      BackupValidationErrorCode.invalidData => backupErrorInvalidData,
      BackupValidationErrorCode.duplicateRecordId =>
        backupErrorDuplicateRecordId,
      BackupValidationErrorCode.duplicateQrId => backupErrorDuplicateQrId,
      BackupValidationErrorCode.invalidQrId => backupErrorInvalidQrId,
      BackupValidationErrorCode.invalidEnum => backupErrorInvalidEnum,
      BackupValidationErrorCode.brokenRelationship =>
        backupErrorBrokenRelationship,
      BackupValidationErrorCode.invalidLifecycle => backupErrorInvalidLifecycle,
      BackupValidationErrorCode.invalidSettings => backupErrorInvalidSettings,
      BackupValidationErrorCode.invalidMediaReference =>
        backupErrorInvalidMediaReference,
      BackupValidationErrorCode.missingMedia => backupErrorMissingMedia,
      BackupValidationErrorCode.emptyMedia => backupErrorEmptyMedia,
    };
  }
}
