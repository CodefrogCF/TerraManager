import 'package:flutter/material.dart';

import 'app.dart';
import 'core/database/app_database.dart';

void main() {
  final database = AppDatabase();

  runApp(
    TerraManagerApp(
      database: database,
    ),
  );
}