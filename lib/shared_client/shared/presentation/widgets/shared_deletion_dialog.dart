import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

Future<bool> confirmPermanentDeletion(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          sharedText(context, 'Delete permanently?', 'Endgültig löschen?'),
        ),
        content: Text(
          sharedText(
            context,
            'This cannot be undone.',
            'Dies kann nicht rückgängig gemacht werden.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(sharedText(context, 'Delete', 'Löschen')),
          ),
        ],
      ),
    ) ??
    false;
