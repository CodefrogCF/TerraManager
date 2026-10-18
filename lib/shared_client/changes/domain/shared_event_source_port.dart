/// A dedicated streaming transport. JSON API requests must never buffer SSE.
abstract class SharedEventSourcePort {
  bool get supported;
  void open(
    Uri url, {
    required void Function() onOpen,
    required void Function(String event, String data, String id) onMessage,
    required void Function() onError,
  });
  void close();
}
