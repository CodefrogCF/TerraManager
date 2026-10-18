import 'package:terramanager/shared_client/changes/domain/shared_event_source_port.dart';

SharedEventSourcePort createSharedEventSource() => _UnsupportedSource();

class _UnsupportedSource implements SharedEventSourcePort {
  @override
  bool get supported => false;
  @override
  void open(
    Uri url, {
    required void Function() onOpen,
    required void Function(String event, String data, String id) onMessage,
    required void Function() onError,
  }) => throw UnsupportedError('EventSource requires a browser.');
  @override
  void close() {}
}
