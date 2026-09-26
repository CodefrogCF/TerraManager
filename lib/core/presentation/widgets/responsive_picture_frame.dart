import 'package:flutter/material.dart';

/// Gives wide record pictures more height without enlarging phone previews.
/// Loading, missing-picture and image states use the same dimensions.
class ResponsivePictureFrame extends StatelessWidget {
  const ResponsivePictureFrame({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: double.infinity,
          height: height ?? (constraints.maxWidth / 2).clamp(220.0, 360.0),
          child: child,
        ),
      ),
    ),
  );
}
