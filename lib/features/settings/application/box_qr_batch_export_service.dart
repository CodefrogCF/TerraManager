import '../../../core/database/app_database.dart';
import '../../../core/qr/qr_export_service.dart';
import '../../../core/qr/qr_file_name.dart';
import '../../../core/qr/qr_storage_service.dart';

class BoxQrExportFailure {
  final Box box;
  final Object error;

  const BoxQrExportFailure({required this.box, required this.error});
}

class BoxQrBatchExportResult {
  final List<Box> succeeded;
  final List<BoxQrExportFailure> failures;

  BoxQrBatchExportResult({
    required Iterable<Box> succeeded,
    required Iterable<BoxQrExportFailure> failures,
  }) : succeeded = List<Box>.unmodifiable(succeeded),
       failures = List<BoxQrExportFailure>.unmodifiable(failures);

  bool get isCompleteSuccess => failures.isEmpty;
  bool get isCompleteFailure => succeeded.isEmpty && failures.isNotEmpty;
}

class BoxQrBatchExportService {
  final QrExporter qrExporter;
  final QrStorage qrStorage;

  const BoxQrBatchExportService({
    required this.qrExporter,
    required this.qrStorage,
  });

  Future<BoxQrBatchExportResult> exportBoxes(Iterable<Box> boxes) async {
    final uniqueBoxes = <int, Box>{for (final box in boxes) box.id: box}.values
        .toList(growable: false);

    if (uniqueBoxes.isEmpty) {
      throw ArgumentError.value(boxes, 'boxes', 'Select at least one Box.');
    }

    final succeeded = <Box>[];
    final failures = <BoxQrExportFailure>[];

    for (final box in uniqueBoxes) {
      try {
        final pngBytes = await qrExporter.exportPng(qrId: box.qrId);
        await qrStorage.savePng(
          bytes: pngBytes,
          fileName: buildBoxQrFileName(box.qrId),
        );
        succeeded.add(box);
      } catch (error) {
        failures.add(BoxQrExportFailure(box: box, error: error));
      }
    }

    return BoxQrBatchExportResult(succeeded: succeeded, failures: failures);
  }
}
