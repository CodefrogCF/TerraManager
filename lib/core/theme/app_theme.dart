import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme({required Color seedColor}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      fontFamily: kIsWeb ? 'NotoSans' : null,
      useMaterial3: true,
    );
  }

  static ThemeData darkTheme({required Color seedColor}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      fontFamily: kIsWeb ? 'NotoSans' : null,
      useMaterial3: true,
    );
  }
}
