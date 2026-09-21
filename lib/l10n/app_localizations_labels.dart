import 'package:flutter/material.dart';

import '../core/database/enums/animal_archive_reason.dart';
import '../core/database/enums/animal_category.dart';
import '../core/database/enums/box_archive_reason.dart';
import '../core/database/enums/birth_date_accuracy.dart';
import '../core/database/enums/sex.dart';
import '../features/backup/application/backup_validation_exception.dart';
import '../features/settings/app_accent.dart';
import '../features/settings/app_language.dart';
import '../features/settings/animal_name_order.dart';
import '../features/settings/animal_sort_order.dart';
import '../features/settings/box_sort_order.dart';
import '../features/settings/archive_sort_order.dart';
import 'generated/app_localizations.dart';

extension AppLocalizationsLabels on AppLocalizations {
  String animalCategoryLabel(AnimalCategory category) {
    return switch (category) {
      AnimalCategory.amphibian => categoryAmphibian,
      AnimalCategory.reptile => categoryReptile,
      AnimalCategory.arachnid => categoryArachnid,
      AnimalCategory.insect => categoryInsect,
      AnimalCategory.myriapod => categoryMyriapod,
      AnimalCategory.crustacean => categoryCrustacean,
      AnimalCategory.mollusc => categoryMollusc,
      AnimalCategory.otherInvertebrate => categoryOtherInvertebrate,
      AnimalCategory.other => categoryOther,
    };
  }

  String animalSubcategoryLabel(AnimalSubcategory subcategory) {
    return switch (subcategory) {
      AnimalSubcategory.snake => subcategorySnake,
      AnimalSubcategory.lizard => subcategoryLizard,
      AnimalSubcategory.turtle => subcategoryTurtle,
      AnimalSubcategory.frogOrToad => subcategoryFrogOrToad,
      AnimalSubcategory.newtOrSalamander => subcategoryNewtOrSalamander,
      AnimalSubcategory.tarantula => subcategoryTarantula,
      AnimalSubcategory.otherSpider => subcategoryOtherSpider,
      AnimalSubcategory.scorpion => subcategoryScorpion,
      AnimalSubcategory.whipSpiderOrWhipScorpion =>
        subcategoryWhipSpiderOrWhipScorpion,
      AnimalSubcategory.beetle => subcategoryBeetle,
      AnimalSubcategory.cockroach => subcategoryCockroach,
      AnimalSubcategory.mantis => subcategoryMantis,
      AnimalSubcategory.grasshopperOrCricket => subcategoryGrasshopperOrCricket,
      AnimalSubcategory.millipede => subcategoryMillipede,
      AnimalSubcategory.centipede => subcategoryCentipede,
      AnimalSubcategory.isopod => subcategoryIsopod,
      AnimalSubcategory.crab => subcategoryCrab,
      AnimalSubcategory.snail => subcategorySnail,
      AnimalSubcategory.other => subcategoryOther,
    };
  }

  String animalCategoryPluralLabel(AnimalCategory category) {
    return switch (category) {
      AnimalCategory.amphibian => categoryAmphibians,
      AnimalCategory.reptile => categoryReptiles,
      AnimalCategory.arachnid => categoryArachnids,
      AnimalCategory.insect => categoryInsects,
      AnimalCategory.myriapod => categoryMyriapods,
      AnimalCategory.crustacean => categoryCrustaceans,
      AnimalCategory.mollusc => categoryMolluscs,
      AnimalCategory.otherInvertebrate => categoryOtherInvertebrates,
      AnimalCategory.other => categoryOthers,
    };
  }

  String animalSubcategoryPluralLabel(AnimalSubcategory subcategory) {
    return switch (subcategory) {
      AnimalSubcategory.snake => subcategorySnakes,
      AnimalSubcategory.lizard => subcategoryLizards,
      AnimalSubcategory.turtle => subcategoryTurtles,
      AnimalSubcategory.frogOrToad => subcategoryFrogsOrToads,
      AnimalSubcategory.newtOrSalamander => subcategoryNewtsOrSalamanders,
      AnimalSubcategory.tarantula => subcategoryTarantulas,
      AnimalSubcategory.otherSpider => subcategoryOtherSpiders,
      AnimalSubcategory.scorpion => subcategoryScorpions,
      AnimalSubcategory.whipSpiderOrWhipScorpion =>
        subcategoryWhipSpidersOrWhipScorpions,
      AnimalSubcategory.beetle => subcategoryBeetles,
      AnimalSubcategory.cockroach => subcategoryCockroaches,
      AnimalSubcategory.mantis => subcategoryMantises,
      AnimalSubcategory.grasshopperOrCricket =>
        subcategoryGrasshoppersOrCrickets,
      AnimalSubcategory.millipede => subcategoryMillipedes,
      AnimalSubcategory.centipede => subcategoryCentipedes,
      AnimalSubcategory.isopod => subcategoryIsopods,
      AnimalSubcategory.crab => subcategoryCrabs,
      AnimalSubcategory.snail => subcategorySnails,
      AnimalSubcategory.other => subcategoryOthers,
    };
  }

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
      BoxSortOrder.volumeAscending => boxSortVolumeAscending,
      BoxSortOrder.volumeDescending => boxSortVolumeDescending,
    };
  }

  String boxSortCriterionMenuLabel(
    BoxSortCriterion criterion, {
    required BoxSortOrder? activeOrder,
  }) {
    final criterionLabel = switch (criterion) {
      BoxSortCriterion.label => boxSortNumberCriterion,
      BoxSortCriterion.name => boxSortNameCriterion,
      BoxSortCriterion.volume => boxSortVolumeCriterion,
    };

    if (activeOrder == null) {
      return criterionLabel;
    }

    final directionLabel = switch (activeOrder) {
      BoxSortOrder.labelAscending ||
      BoxSortOrder.nameAscending ||
      BoxSortOrder.volumeAscending => sortDirectionAscending,
      BoxSortOrder.labelDescending ||
      BoxSortOrder.nameDescending ||
      BoxSortOrder.volumeDescending => sortDirectionDescending,
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
      AnimalSortOrder.categoryAscending => animalSortCategoryAscending,
      AnimalSortOrder.categoryDescending => animalSortCategoryDescending,
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
      AnimalSortOrder.categoryAscending => sortDirectionAscending,
      AnimalSortOrder.categoryDescending => sortDirectionDescending,
    };

    return sortCriterionWithDirection(criterionLabel, directionLabel);
  }

  String archiveSortCriterionMenuLabel(
    ArchiveSortCriterion criterion, {
    required ArchiveSortOrder? activeOrder,
  }) {
    final criterionLabel = switch (criterion) {
      ArchiveSortCriterion.archivedAt => archiveDate,
      ArchiveSortCriterion.name => archiveSortNameCriterion,
    };

    if (activeOrder == null) {
      return criterionLabel;
    }

    final directionLabel = switch (activeOrder) {
      ArchiveSortOrder.archivedNewestFirst => sortDirectionNewestFirst,

      ArchiveSortOrder.archivedOldestFirst => sortDirectionOldestFirst,

      ArchiveSortOrder.nameAscending => sortDirectionAscending,

      ArchiveSortOrder.nameDescending => sortDirectionDescending,
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
