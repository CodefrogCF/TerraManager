import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/l10n/app_localizations_labels.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  test('Box archive reasons have English and German labels', () {
    final english = lookupAppLocalizations(const Locale('en'));
    final german = lookupAppLocalizations(const Locale('de'));
    expect(BoxArchiveReason.values.map(english.boxArchiveReasonLabel), [
      'Sold',
      'Replaced',
      'Damaged',
      'Other',
    ]);
    expect(BoxArchiveReason.values.map(german.boxArchiveReasonLabel), [
      'Verkauft',
      'Ersetzt',
      'Beschädigt',
      'Sonstiges',
    ]);
  });
}
