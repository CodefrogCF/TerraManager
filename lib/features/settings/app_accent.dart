import 'package:flutter/material.dart';

enum AppAccent {
  green(
    label: 'Green',
    color: Color.fromARGB(255, 0, 255, 76),
  ),
  blue(
    label: 'Blue',
    color: Colors.blue,
  ),
  teal(
    label: 'Teal',
    color: Colors.teal,
  ),
  orange(
    label: 'Orange',
    color: Colors.orange,
  ),
  purple(
    label: 'Purple',
    color: Colors.purple,
  ),
  red(
    label: 'Red',
    color: Colors.red,
  );

  final String label;
  final Color color;

  const AppAccent({
    required this.label,
    required this.color,
  });
}