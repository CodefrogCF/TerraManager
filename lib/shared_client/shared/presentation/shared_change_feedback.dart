import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

void showSharedChangeFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        sharedText(
          context,
          'Could not save. Reload and check the server state.',
          'Speichern fehlgeschlagen. Neu laden und Serverstand prüfen.',
        ),
      ),
    ),
  );
}
