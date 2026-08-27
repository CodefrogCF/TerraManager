String buildBoxQrFileName(String qrId) {
  final safeQrId = qrId
      .replaceAll(':', '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  return 'terramanager_$safeQrId';
}