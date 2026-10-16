import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/animals/application/animal_profile_pdf_export_service.dart';
import 'package:terramanager/features/animals/presentation/widgets/animal_profile_pdf_export_button.dart';
import 'package:terramanager/features/settings/infrastructure/box_qr_document_storage_service.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

class _Exporter implements AnimalProfilePdfExporter {
  AnimalProfilePdfOptions? lastOptions;

  @override
  Future<Uint8List> export(
    AnimalProfilePdfData data,
    AnimalProfilePdfOptions options,
  ) async {
    lastOptions = options;
    return Uint8List.fromList([37, 80, 68, 70]);
  }
}

class _Storage implements BoxQrDocumentStorage {
  int calls = 0;
  String? result;
  String? fileName;

  @override
  Future<String?> saveDocument({
    required Uint8List bytes,
    required String fileName,
    required BoxQrDocumentType type,
  }) async {
    calls++;
    this.fileName = fileName;
    expect(type, BoxQrDocumentType.pdf);
    return result;
  }
}

void main() {
  testWidgets('offers both formats and treats save cancellation silently', (
    tester,
  ) async {
    final storage = _Storage();
    final exporter = _Exporter();
    final galleryRequests = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AnimalProfilePdfExportButton(
                storage: storage,
                exporter: exporter,
                loadData: (includeGallery) async {
                  galleryRequests.add(includeGallery);
                  return const AnimalProfilePdfData(
                    name: 'Schlange',
                    fields: [],
                    feedingTitle: 'Fütterung',
                    sheddingTitle: 'Häutung',
                    weightTitle: 'Gewicht',
                    galleryTitle: 'Bilder',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('animal-profile-pdf-export-button')));
    await tester.pumpAndSettle();
    expect(find.text('Terrarium-Etikett / Aufsteller'), findsOneWidget);
    expect(
      find.text('Vollständiges A4-Datenblatt mit Historie'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('animal-pdf-handover-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('animal-pdf-include-gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('animal-pdf-save-option')));
    await tester.pumpAndSettle();

    expect(galleryRequests, [true]);
    expect(exporter.lastOptions!.kind, AnimalProfilePdfKind.handover);
    expect(exporter.lastOptions!.includeGallery, isTrue);
    expect(storage.calls, 1);
    expect(storage.fileName, endsWith('_A4.pdf'));
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const Key('animal-profile-pdf-export-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(storage.calls, 1);
  });
}
