import 'package:flutter/material.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

class SharedLoadFailure extends StatelessWidget {
  const SharedLoadFailure({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: onRetry,
      child: Text(
        sharedText(
          context,
          'Could not load. Retry',
          'Laden fehlgeschlagen. Erneut versuchen',
        ),
      ),
    ),
  );
}
