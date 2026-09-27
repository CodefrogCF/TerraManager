import 'package:flutter/material.dart';

PopupMenuItem<T> sharedMenuItem<T>(T value, IconData icon, String label) =>
    PopupMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      ),
    );
