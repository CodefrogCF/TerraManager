import 'dart:typed_data';

typedef ApiPayload = Map<String, dynamic>;

class ApiReply {
  final int status;
  final ApiPayload? body;
  final Uint8List? bytes;
  final String? mimeType;
  final bool replayed;

  const ApiReply(this.status, this.body, {this.replayed = false})
    : bytes = null,
      mimeType = null;

  const ApiReply.bytes(this.status, this.bytes, this.mimeType)
    : body = null,
      replayed = false;
}

ApiReply apiError(int status, String code, String message) => ApiReply(status, {
  'error': {'code': code, 'message': message},
});
