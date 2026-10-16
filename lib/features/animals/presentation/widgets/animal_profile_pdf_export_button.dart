import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations_context.dart';
import '../../../settings/infrastructure/box_qr_document_storage_service.dart';
import '../../application/animal_profile_pdf_export_service.dart';

typedef AnimalProfilePdfDataLoader = Future<AnimalProfilePdfData> Function(
  bool includeGallery,
);

class AnimalProfilePdfExportButton extends StatefulWidget {
  const AnimalProfilePdfExportButton({
    super.key,
    required this.loadData,
    this.storage = const BoxQrDocumentStorageService(),
    this.exporter = const AnimalProfilePdfExportService(),
  });

  final AnimalProfilePdfDataLoader loadData;
  final BoxQrDocumentStorage storage;
  final AnimalProfilePdfExporter exporter;

  @override
  State<AnimalProfilePdfExportButton> createState() =>
      _AnimalProfilePdfExportButtonState();
}

class _AnimalProfilePdfExportButtonState
    extends State<AnimalProfilePdfExportButton> {
  bool _busy = false;

  Future<void> _export() async {
    final options = await showDialog<AnimalProfilePdfOptions>(
      context: context,
      builder: (_) => const _AnimalProfilePdfOptionsDialog(),
    );
    if (!mounted || options == null) return;
    setState(() => _busy = true);
    try {
      final data = await widget.loadData(
        options.kind == AnimalProfilePdfKind.handover && options.includeGallery,
      );
      final bytes = await widget.exporter.export(data, options);
      final safeName = data.name
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final suffix = options.kind == AnimalProfilePdfKind.label
          ? 'Label'
          : 'A4';
      final saved = await widget.storage.saveDocument(
        bytes: bytes,
        fileName:
            'TerraManager_Animal_${safeName.isEmpty ? 'Profile' : safeName}_$suffix.pdf',
        type: BoxQrDocumentType.pdf,
      );
      if (mounted && saved != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.animalPdfSaved)));
      }
    } catch (error, stackTrace) {
      debugPrint('Animal PDF export failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.animalPdfFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('animal-profile-pdf-export-button'),
    tooltip: context.l10n.exportAnimalPdf,
    onPressed: _busy ? null : _export,
    icon: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.picture_as_pdf_outlined),
  );
}

class _AnimalProfilePdfOptionsDialog extends StatefulWidget {
  const _AnimalProfilePdfOptionsDialog();

  @override
  State<_AnimalProfilePdfOptionsDialog> createState() =>
      _AnimalProfilePdfOptionsDialogState();
}

class _AnimalProfilePdfOptionsDialogState
    extends State<_AnimalProfilePdfOptionsDialog> {
  AnimalProfilePdfKind _kind = AnimalProfilePdfKind.label;
  double _width = defaultAnimalLabelWidthMm;
  bool _includeGallery = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.exportAnimalPdf),
    scrollable: true,
    content: RadioGroup<AnimalProfilePdfKind>(
      groupValue: _kind,
      onChanged: (value) {
        if (value != null) setState(() => _kind = value);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile<AnimalProfilePdfKind>(
            key: const Key('animal-pdf-label-option'),
            title: Text(context.l10n.animalPdfLabel),
            value: AnimalProfilePdfKind.label,
          ),
          if (_kind == AnimalProfilePdfKind.label) ...[
            Text(context.l10n.animalPdfLabelWidth(_width.round())),
            Slider(
              key: const Key('animal-pdf-label-width'),
              min: minimumAnimalLabelWidthMm,
              max: maximumAnimalLabelWidthMm,
              divisions: (maximumAnimalLabelWidthMm - minimumAnimalLabelWidthMm)
                  .round(),
              value: _width,
              label: '${_width.round()} mm',
              onChanged: (value) => setState(() => _width = value),
            ),
          ],
          RadioListTile<AnimalProfilePdfKind>(
            key: const Key('animal-pdf-handover-option'),
            title: Text(context.l10n.animalPdfHandover),
            value: AnimalProfilePdfKind.handover,
          ),
          if (_kind == AnimalProfilePdfKind.handover)
            CheckboxListTile(
              key: const Key('animal-pdf-include-gallery'),
              title: Text(context.l10n.animalPdfIncludeGallery),
              value: _includeGallery,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) =>
                  setState(() => _includeGallery = value ?? false),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('animal-pdf-save-option'),
        onPressed: () => Navigator.of(context).pop(
          AnimalProfilePdfOptions(
            kind: _kind,
            labelWidthMm: _width,
            includeGallery: _includeGallery,
          ),
        ),
        child: Text(context.l10n.animalPdfSave),
      ),
    ],
  );
}
