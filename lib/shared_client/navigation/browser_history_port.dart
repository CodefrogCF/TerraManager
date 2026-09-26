abstract class BrowserHistoryPort {
  void initialize(void Function(int depth) onBack);
  void pushDepth(int depth);
  void replaceDepth(int depth);
  void back(int count);
  void dispose();
}
