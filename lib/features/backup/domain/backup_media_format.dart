class BackupMediaFormat {
  BackupMediaFormat._();

  static const String fallbackExtension = 'img';
  static const String fallbackMimeType = 'application/octet-stream';

  static const Map<String, String> _mimeTypeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'heif': 'image/heif',
  };

  static const Map<String, String> _canonicalExtensionByMimeType = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
    'image/bmp': 'bmp',
    'image/heic': 'heic',
    'image/heif': 'heif',
  };

  static String extensionForExport({required String source, String? mimeType}) {
    final sourceExtension = _supportedExtensionFromSource(source);
    final normalizedMimeType = mimeType?.trim().toLowerCase();
    final mimeExtension = _canonicalExtensionByMimeType[normalizedMimeType];

    if (mimeExtension != null) {
      if (sourceExtension != null &&
          _mimeTypeByExtension[sourceExtension] == normalizedMimeType) {
        return sourceExtension;
      }

      return mimeExtension;
    }

    return sourceExtension ?? fallbackExtension;
  }

  static String mimeTypeFromFileName(String fileName) {
    final extension = _extensionFromSource(fileName);

    if (extension == null) {
      return fallbackMimeType;
    }

    return _mimeTypeByExtension[extension] ?? fallbackMimeType;
  }

  static String? _supportedExtensionFromSource(String source) {
    final extension = _extensionFromSource(source);

    if (extension == null || !_mimeTypeByExtension.containsKey(extension)) {
      return null;
    }

    return extension;
  }

  static String? _extensionFromSource(String source) {
    final withoutQuery = source.split('?').first.split('#').first;
    final normalized = withoutQuery.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return null;
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
