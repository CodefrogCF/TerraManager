import 'package:flutter/material.dart';

/// Reserve this much scroll space so the final row can clear both buttons.
class OverviewActionButtons extends StatelessWidget {
  const OverviewActionButtons({
    super.key,
    required this.primary,
    required this.secondary,
  });
  static const bottomPadding = 140.0;
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [secondary, const SizedBox(height: 12), primary],
  );
}
