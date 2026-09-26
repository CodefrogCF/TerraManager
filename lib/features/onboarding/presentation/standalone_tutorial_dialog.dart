import 'package:flutter/material.dart';

import '../../../shared_client/shared_text.dart';

/// A short tour of the existing local workflows. It never creates sample data.
Future<void> showStandaloneTutorial(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _StandaloneTutorialDialog(),
  );
}

class _StandaloneTutorialDialog extends StatefulWidget {
  const _StandaloneTutorialDialog();

  @override
  State<_StandaloneTutorialDialog> createState() =>
      _StandaloneTutorialDialogState();
}

class _StandaloneTutorialDialogState extends State<_StandaloneTutorialDialog> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        icon: Icons.inventory_2_outlined,
        title: sharedText(context, 'Create a Box', 'Box anlegen'),
        body: sharedText(
          context,
          'Start with a Box. You can add its name, dimensions, notes and pictures, then use its QR code for quick access.',
          'Beginne mit einer Box. Du kannst Name, Maße, Notizen und Bilder hinzufügen und später den QR-Code für den schnellen Zugriff verwenden.',
        ),
      ),
      (
        icon: Icons.pets_outlined,
        title: sharedText(context, 'Add an Animal', 'Tier hinzufügen'),
        body: sharedText(
          context,
          'Add an Animal to an active Box. Its details and optional care information stay in your local collection.',
          'Füge einer aktiven Box ein Tier hinzu. Details und optionale Haltungsangaben bleiben in deiner lokalen Sammlung.',
        ),
      ),
      (
        icon: Icons.restaurant_outlined,
        title: sharedText(context, 'Record feeding', 'Fütterung eintragen'),
        body: sharedText(
          context,
          'Record feedings for an Animal and set an optional reminder. Due feedings appear in the Animals overview.',
          'Erfasse Fütterungen für ein Tier und stelle bei Bedarf eine Erinnerung ein. Fällige Fütterungen erscheinen in der Tierübersicht.',
        ),
      ),
      (
        icon: Icons.qr_code_scanner_outlined,
        title: sharedText(
          context,
          'Use Box QR codes',
          'Box-QR-Codes verwenden',
        ),
        body: sharedText(
          context,
          'Find a Box by scanning its code, or use the QR feeding and rehouse actions when you need them. Scanning starts only when you choose an action.',
          'Finde eine Box über ihren QR-Code oder nutze bei Bedarf QR-Fütterung und QR-Umsetzen. Die Kamera startet erst, wenn du eine Aktion auswählst.',
        ),
      ),
    ];
    final current = steps[_step];
    final last = _step == steps.length - 1;

    return AlertDialog(
      key: const Key('standalone-tutorial-dialog'),
      title: Text(sharedText(context, 'Getting started', 'Erste Schritte')),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sharedText(
                  context,
                  'Step ${_step + 1} of ${steps.length}',
                  'Schritt ${_step + 1} von ${steps.length}',
                ),
                key: const Key('standalone-tutorial-progress'),
              ),
              const SizedBox(height: 20),
              Icon(current.icon, size: 48),
              const SizedBox(height: 12),
              Text(
                current.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(current.body),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('standalone-tutorial-skip'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(sharedText(context, 'Skip', 'Überspringen')),
        ),
        if (_step > 0)
          TextButton(
            key: const Key('standalone-tutorial-back'),
            onPressed: () => setState(() => _step--),
            child: Text(sharedText(context, 'Back', 'Zurück')),
          ),
        FilledButton(
          key: const Key('standalone-tutorial-next'),
          onPressed: last
              ? () => Navigator.of(context).pop()
              : () => setState(() => _step++),
          child: Text(
            last
                ? sharedText(context, 'Finish', 'Fertig')
                : sharedText(context, 'Next', 'Weiter'),
          ),
        ),
      ],
    );
  }
}
