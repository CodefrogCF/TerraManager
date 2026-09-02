import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String generateBoxQrId() {
  return 'TM:BOX:${_uuid.v4()}';
}
