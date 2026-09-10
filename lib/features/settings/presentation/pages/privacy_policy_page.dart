import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class PrivacyPolicyPage extends StatelessWidget {
  final String title;
  final String? policyText;

  const PrivacyPolicyPage({super.key, required this.title, this.policyText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('privacy-policy-page'),
      appBar: AppBar(title: Text(title)),
      body: policyText != null
          ? Markdown(
              key: const Key('privacy-policy-content'),
              data: policyText!,
              selectable: true,
            )
          : FutureBuilder<String>(
              future: rootBundle.loadString('PRIVACY.md'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'The privacy policy could not be loaded.',
                        key: Key('privacy-policy-load-error'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      key: Key('privacy-policy-loading'),
                    ),
                  );
                }

                return Markdown(
                  key: const Key('privacy-policy-content'),
                  data: snapshot.data!,
                  selectable: true,
                );
              },
            ),
    );
  }
}
