import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class LegalDocumentPage extends StatefulWidget {
  final String title;
  final String assetPath;
  final String loadErrorText;
  final String? documentText;
  final String? documentPreamble;
  final Key pageKey;
  final Key contentKey;
  final Key loadingKey;
  final Key loadErrorKey;

  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.assetPath,
    required this.loadErrorText,
    required this.pageKey,
    required this.contentKey,
    required this.loadingKey,
    required this.loadErrorKey,
    this.documentText,
    this.documentPreamble,
  });

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  Future<String>? _documentFuture;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void didUpdateWidget(covariant LegalDocumentPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.assetPath != widget.assetPath ||
        (oldWidget.documentText == null) != (widget.documentText == null)) {
      _loadDocument();
    }
  }

  void _loadDocument() {
    _documentFuture = widget.documentText == null
        ? rootBundle.loadString(widget.assetPath)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: widget.pageKey,
      appBar: AppBar(title: Text(widget.title)),
      body: widget.documentText != null
          ? _buildMarkdown(widget.documentText!)
          : FutureBuilder<String>(
              future: _documentFuture!,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.loadErrorText,
                        key: widget.loadErrorKey,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(key: widget.loadingKey),
                  );
                }

                return _buildMarkdown(snapshot.data!);
              },
            ),
    );
  }

  Widget _buildMarkdown(String document) {
    final preamble = widget.documentPreamble?.trim();
    final data = preamble == null || preamble.isEmpty
        ? document
        : '$preamble\n\n---\n\n$document';

    return Markdown(key: widget.contentKey, data: data, selectable: true);
  }
}
