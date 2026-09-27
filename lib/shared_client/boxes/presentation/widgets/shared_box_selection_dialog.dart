import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

Future<int?> selectActiveBox(
  BuildContext context,
  List<Map<String, dynamic>> boxes,
) async => showDialog<int>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(sharedText(context, 'Choose Box', 'Box auswählen')),
    children: [
      for (final box in boxes.where((box) => box['status'] == 'active'))
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(recordId(box)),
          child: Text(boxLabel(box)),
        ),
    ],
  ),
);
