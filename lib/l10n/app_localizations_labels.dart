import 'package:flutter/material.dart';

import '../core/database/enums/animal_archive_reason.dart';
import '../core/database/enums/birth_date_accuracy.dart';
import '../core/database/enums/sex.dart';
import '../features/backup/application/backup_validation_exception.dart';
import '../features/settings/app_accent.dart';
import '../features/settings/app_language.dart';
import 'generated/app_localizations.dart';

extension AppLocalizationsLabels on AppLocalizations {
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
