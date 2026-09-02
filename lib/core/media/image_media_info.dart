import 'package:image_picker/image_picker.dart';

class ImageMediaInfo {
  final String fileName;
  final String mimeType;

  const ImageMediaInfo({required this.fileName, required this.mimeType});

  factory ImageMediaInfo.fromXFile(XFile file) {
    final providedName = file.name.trim();

    final fileName = providedName.isNotEmpty
        ? providedName
        : _fileNameFromPath(file.path);

    final providedMimeType = file.mimeType?.trim();

    return ImageMediaInfo(
      fileName: fileName.isEmpty ? 'image.img' : fileName,
      mimeType: providedMimeType != null && providedMimeType.isNotEmpty
          ? providedMimeType
          : _mimeTypeFromFileName(fileName),
    );
  }

  static String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');

    return normalized.split('/').last;
  }

  static String _mimeTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }

    if (lower.endsWith('.bmp')) {
      return 'image/bmp';
    }

    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }

    if (lower.endsWith('.heif')) {
      return 'image/heif';
    }

    return 'application/octet-stream';
  }
}
