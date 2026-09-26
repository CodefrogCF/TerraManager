import 'package:flutter/material.dart';

/// Keeps reading and editing surfaces comfortable on wide desktop windows.
/// On narrower screens the child still occupies the full available width.
class ConstrainedPageWidth extends StatelessWidget {
  const ConstrainedPageWidth({
    super.key,
    required this.child,
    this.maxWidth = 960,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox.expand(child: child),
      ),
    ),
  );
}
