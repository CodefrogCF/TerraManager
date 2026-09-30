import 'package:file_saver/file_saver_web.dart';

bool get supportsStreamedBackupSaving => FileSaverWeb.canSaveStream;

// showSaveFilePicker rejects with AbortError when the user closes the picker.
bool isStreamSaveCancellation(Object error) =>
    error.toString().contains('AbortError');
