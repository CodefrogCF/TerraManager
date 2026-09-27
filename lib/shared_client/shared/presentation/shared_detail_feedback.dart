import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

void leaveRemovedSharedDetail(BuildContext context) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  final messenger = ScaffoldMessenger.of(context);
  final message = sharedText(
    context,
    'This record is no longer available in the current overview.',
    'Dieser Eintrag ist in der aktuellen Übersicht nicht mehr verfügbar.',
  );
  Navigator.of(context).pop();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

void showSharedDetailFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        sharedText(
          context,
          'The request failed. Reload and check the server state.',
          'Die Anfrage ist fehlgeschlagen. Neu laden und Serverstand prüfen.',
        ),
      ),
    ),
  );
}
