import 'browser_history_port.dart';

BrowserHistoryPort createBrowserHistory() => _NoBrowserHistory();

class _NoBrowserHistory implements BrowserHistoryPort {
  @override
  void initialize(void Function(int depth) onBack) {}
  @override
  void pushDepth(int depth) {}
  @override
  void replaceDepth(int depth) {}
  @override
  void back(int count) {}
  @override
  void dispose() {}
}
