import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../core/qr/qr_export_service.dart';
import '../core/qr/qr_file_name.dart';
import '../core/qr/qr_validator.dart';
import '../features/settings/application/box_qr_pdf_export_service.dart';
import '../features/settings/infrastructure/box_qr_document_storage_service.dart';
import '../features/settings/presentation/box_qr_selection_dialog.dart';
import '../l10n/app_localizations_context.dart';
import 'shared_api_client.dart';

/// An export input read from the care API, never from browser-local storage.
class SharedBoxQrRecord {
  const SharedBoxQrRecord({
    required this.id,
    required this.qrId,
    required this.archived,
    this.name,
  });

  factory SharedBoxQrRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final qrId = json['qrId'];
    final status = json['status'];
    if (id is! int ||
        qrId is! String ||
        !isValidBoxQrId(qrId) ||
        (status != 'active' && status != 'archived')) {
      throw const FormatException('Invalid Box QR export data from server.');
    }
    return SharedBoxQrRecord(
      id: id,
      qrId: qrId,
      archived: status == 'archived',
      name: json['name'] as String?,
    );
  }

  final int id;
  final String qrId;
  final String? name;
  final bool archived;

  String get displayLabel {
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty
        ? 'Box $id'
        : '$trimmed · Box $id';
  }
}

List<SharedBoxQrRecord> selectSharedBoxQrRecords(
  Iterable<SharedBoxQrRecord> records,
  Set<int> selectedIds,
) => <int, SharedBoxQrRecord>{
  for (final record in records)
    if (selectedIds.contains(record.id)) record.id: record,
}.values.toList(growable: false);

abstract class SharedBoxQrDownloader {
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
}

class BrowserBoxQrDownloader implements SharedBoxQrDownloader {
  const BrowserBoxQrDownloader();

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async =>
      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        includeExtension: false,
        mimeType: MimeType.custom,
        customMimeType: mimeType,
      ) !=
      null;
}

class SharedBoxQrExportResult {
  const SharedBoxQrExportResult({required this.saved, required this.failed});
  final int saved;
  final int failed;
}

class SharedBoxQrExportService {
  const SharedBoxQrExportService({
    this.qrExporter = const QrExportService(),
    this.downloader = const BrowserBoxQrDownloader(),
    this.pdfExporter = const BoxQrPdfExportService(),
  });

  final QrExporter qrExporter;
  final SharedBoxQrDownloader downloader;
  final BoxQrPdfExportService pdfExporter;

  Future<SharedBoxQrExportResult> export(
    BoxQrExportKind kind,
    Iterable<SharedBoxQrRecord> records, {
    double qrSizeMm = defaultBoxQrPdfSizeMm,
  }) async {
    final unique = <int, SharedBoxQrRecord>{
      for (final record in records) record.id: record,
    }.values.toList(growable: false);
    if (unique.isEmpty) {
      throw ArgumentError.value(records, 'records', 'Select at least one Box.');
    }
    if (unique.map((record) => record.qrId).toSet().length != unique.length) {
      throw const FormatException('Duplicate Box QR identifiers.');
    }
    switch (kind) {
      case BoxQrExportKind.images:
        var saved = 0;
        var failed = 0;
        for (final box in unique) {
          try {
            final bytes = await qrExporter.exportPng(qrId: box.qrId);
            final downloaded = await downloader.save(
              fileName: '${buildBoxQrFileName(box.qrId)}.png',
              bytes: bytes,
              mimeType: 'image/png',
            );
            if (downloaded) {
              saved++;
            } else {
              failed++;
            }
          } catch (_) {
            failed++;
          }
        }
        return SharedBoxQrExportResult(saved: saved, failed: failed);
      case BoxQrExportKind.zip:
        final archive = Archive();
        for (final box in unique) {
          final bytes = await qrExporter.exportPng(qrId: box.qrId);
          archive.add(
            ArchiveFile.bytes('${buildBoxQrFileName(box.qrId)}.png', bytes),
          );
        }
        final downloaded = await downloader.save(
          fileName: boxQrZipFileName,
          bytes: Uint8List.fromList(ZipEncoder().encodeBytes(archive)),
          mimeType: 'application/zip',
        );
        return SharedBoxQrExportResult(
          saved: downloaded ? unique.length : 0,
          failed: downloaded ? 0 : unique.length,
        );
      case BoxQrExportKind.pdf:
        final bytes = await pdfExporter.exportItems([
          for (final box in unique)
            BoxQrPdfItem(
              boxId: box.id,
              qrPayload: box.qrId,
              label: boxQrPdfLabel(box.id, box.name, qrSizeMm),
            ),
        ], qrSizeMm: qrSizeMm);
        final downloaded = await downloader.save(
          fileName: boxQrPdfFileName,
          bytes: bytes,
          mimeType: 'application/pdf',
        );
        return SharedBoxQrExportResult(
          saved: downloaded ? unique.length : 0,
          failed: downloaded ? 0 : unique.length,
        );
    }
  }
}

class SharedBoxQrExportSection extends StatefulWidget {
  const SharedBoxQrExportSection({
    super.key,
    required this.api,
    required this.enabled,
    this.exporter = const SharedBoxQrExportService(),
  });

  final SharedApiClient api;
  final bool enabled;
  final SharedBoxQrExportService exporter;

  @override
  State<SharedBoxQrExportSection> createState() =>
      _SharedBoxQrExportSectionState();
}

class _SharedBoxQrExportSectionState extends State<SharedBoxQrExportSection> {
  bool _busy = false;

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  Future<void> _export(BoxQrExportKind kind) async {
    if (_busy || !widget.enabled || !widget.api.connected) return;
    setState(() => _busy = true);
    try {
      final records = (await widget.api.boxes())
          .map(SharedBoxQrRecord.fromJson)
          .toList(growable: false);
      if (!mounted) return;
      if (records.isEmpty) {
        _message(context.l10n.noBoxesAvailable);
        return;
      }
      setState(() => _busy = false);
      final selection = await showDialog<({Set<int> ids, double sizeMm})>(
        context: context,
        builder: (_) =>
            _SharedBoxQrSelectionDialog(records: records, kind: kind),
      );
      if (!mounted || selection == null) return;
      final selected = selectSharedBoxQrRecords(records, selection.ids);
      if (selected.isEmpty) return;
      setState(() => _busy = true);
      final result = await widget.exporter.export(
        kind,
        selected,
        qrSizeMm: selection.sizeMm,
      );
      if (!mounted) return;
      if (result.failed != 0) {
        _message(context.l10n.boxQrExportPartial(result.saved, result.failed));
      } else {
        _message(switch (kind) {
          BoxQrExportKind.images => context.l10n.boxQrExportSucceeded(
            result.saved,
          ),
          BoxQrExportKind.zip => context.l10n.boxQrZipExportSucceeded(
            result.saved,
          ),
          BoxQrExportKind.pdf => context.l10n.boxQrPdfExportSucceeded(
            result.saved,
          ),
        });
      }
    } catch (_) {
      if (mounted) {
        _message(switch (kind) {
          BoxQrExportKind.images => context.l10n.failedToSaveBoxQrCodes,
          BoxQrExportKind.zip => context.l10n.failedToSaveBoxQrCodesAsZip,
          BoxQrExportKind.pdf => context.l10n.failedToSaveBoxQrCodesAsPdf,
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.boxQrCodes,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(context.l10n.boxQrCodesSectionDescription),
      if (_busy) const LinearProgressIndicator(),
      const SizedBox(height: 8),
      for (final kind in BoxQrExportKind.values) ...[
        if (kind != BoxQrExportKind.images) const Divider(),
        ListTile(
          key: Key('shared-box-qr-export-${kind.name}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(switch (kind) {
            BoxQrExportKind.images => Icons.qr_code_2,
            BoxQrExportKind.zip => Icons.folder_zip_outlined,
            BoxQrExportKind.pdf => Icons.picture_as_pdf_outlined,
          }),
          title: Text(switch (kind) {
            BoxQrExportKind.images => context.l10n.saveBoxQrCodes,
            BoxQrExportKind.zip => context.l10n.saveBoxQrCodesAsZip,
            BoxQrExportKind.pdf => context.l10n.saveBoxQrCodesAsPdf,
          }),
          subtitle: Text(switch (kind) {
            BoxQrExportKind.images => context.l10n.saveBoxQrCodesDescription,
            BoxQrExportKind.zip => context.l10n.saveBoxQrCodesAsZipDescription,
            BoxQrExportKind.pdf => context.l10n.saveBoxQrCodesAsPdfDescription,
          }),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy || !widget.enabled || !widget.api.connected
              ? null
              : () => _export(kind),
        ),
      ],
    ],
  );
}

class _SharedBoxQrSelectionDialog extends StatefulWidget {
  const _SharedBoxQrSelectionDialog({
    required this.records,
    required this.kind,
  });
  final List<SharedBoxQrRecord> records;
  final BoxQrExportKind kind;

  @override
  State<_SharedBoxQrSelectionDialog> createState() =>
      _SharedBoxQrSelectionDialogState();
}

class _SharedBoxQrSelectionDialogState
    extends State<_SharedBoxQrSelectionDialog> {
  late final Set<int> _selected = widget.records.map((box) => box.id).toSet();
  double _sizeMm = defaultBoxQrPdfSizeMm;

  @override
  Widget build(BuildContext context) {
    final active = widget.records.where((box) => !box.archived).toList();
    final archived = widget.records.where((box) => box.archived).toList();
    final rows = <Object>[
      if (active.isNotEmpty) context.l10n.activeBoxes,
      ...active,
      if (archived.isNotEmpty) context.l10n.archivedBoxes,
      ...archived,
    ];
    return AlertDialog(
      key: const Key('shared-box-qr-selection-dialog'),
      title: Text(switch (widget.kind) {
        BoxQrExportKind.images => context.l10n.saveBoxQrCodes,
        BoxQrExportKind.zip => context.l10n.saveBoxQrCodesAsZip,
        BoxQrExportKind.pdf => context.l10n.saveBoxQrCodesAsPdf,
      }),
      content: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Text(switch (widget.kind) {
              BoxQrExportKind.images => context.l10n.saveBoxQrCodesDescription,
              BoxQrExportKind.zip =>
                context.l10n.saveBoxQrCodesAsZipDescription,
              BoxQrExportKind.pdf =>
                context.l10n.saveBoxQrCodesAsPdfDescription,
            }),
            if (widget.kind == BoxQrExportKind.pdf) ...[
              const SizedBox(height: 8),
              Text(context.l10n.boxQrCodeSizeValue(_sizeMm.round())),
              Slider(
                key: const Key('shared-box-qr-size-slider'),
                min: minimumBoxQrPdfSizeMm,
                max: maximumBoxQrPdfSizeMm,
                divisions: 14,
                value: _sizeMm,
                label: context.l10n.boxQrCodeSizeValue(_sizeMm.round()),
                semanticFormatterCallback: (value) =>
                    context.l10n.boxQrCodeSizeValue(value.round()),
                onChanged: (value) => setState(() => _sizeMm = value),
              ),
            ],
            Wrap(
              children: [
                TextButton(
                  onPressed: _selected.length == widget.records.length
                      ? null
                      : () => setState(
                          () => _selected.addAll(
                            widget.records.map((box) => box.id),
                          ),
                        ),
                  child: Text(context.l10n.selectAll),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(_selected.clear),
                  child: Text(context.l10n.clearSelection),
                ),
              ],
            ),
            if (_selected.isEmpty)
              Text(
                context.l10n.selectAtLeastOneBox,
                key: const Key('shared-box-qr-empty-selection'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  if (row is String) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        row,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    );
                  }
                  final box = row as SharedBoxQrRecord;
                  return CheckboxListTile(
                    key: Key('shared-box-qr-checkbox-${box.id}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _selected.contains(box.id),
                    title: Text(box.displayLabel),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(box.id);
                      } else {
                        _selected.remove(box.id);
                      }
                    }),
                  );
                },
              ),
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
          key: const Key('shared-box-qr-confirm'),
          onPressed: _selected.isEmpty
              ? null
              : () =>
                    Navigator.of(context)
                        .pop((ids: Set<int>.of(_selected), sizeMm: _sizeMm)),
          child: Text(switch (widget.kind) {
            BoxQrExportKind.images => context.l10n.saveSelectedQrCodes,
            BoxQrExportKind.zip => context.l10n.saveSelectedQrCodesAsZip,
            BoxQrExportKind.pdf => context.l10n.saveSelectedQrCodesAsPdf,
          }),
        ),
      ],
    );
  }
}
