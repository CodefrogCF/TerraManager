import 'package:flutter/material.dart';

enum AppAccent {
  green(color: Color.fromARGB(255, 0, 163, 49)),
  blue(color: Colors.blue),
  teal(color: Colors.teal),
  orange(color: Colors.orange),
  purple(color: Colors.purple),
  red(color: Colors.red);

  final Color color;

  const AppAccent({required this.color});
}
