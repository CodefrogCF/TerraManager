import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class LegalDocumentPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      key: pageKey,
      appBar: AppBar(title: Text(title)),
      body: documentText != null
          ? _buildMarkdown(documentText!)
          : FutureBuilder<String>(
              future: rootBundle.loadString(assetPath),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        loadErrorText,
                        key: loadErrorKey,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(key: loadingKey),
                  );
                }

                return _buildMarkdown(snapshot.data!);
              },
            ),
    );
  }

  Widget _buildMarkdown(String document) {
    final preamble = documentPreamble?.trim();
    final data = preamble == null || preamble.isEmpty
        ? document
        : '$preamble\n\n---\n\n$document';

    return Markdown(key: contentKey, data: data, selectable: true);
  }
}
