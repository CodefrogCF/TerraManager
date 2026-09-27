import 'package:flutter/material.dart';
import 'package:terramanager/features/backup/domain/backup_timestamps.dart';
import 'package:terramanager/shared_client/backups/infrastructure/source_time_zone.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

Future<String?> selectLegacyBackupTimeZone(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _LegacyTimeZoneDialog(),
    );

class _LegacyTimeZoneDialog extends StatefulWidget {
  const _LegacyTimeZoneDialog();
  @override
  State<_LegacyTimeZoneDialog> createState() => _LegacyTimeZoneDialogState();
}

class _LegacyTimeZoneDialogState extends State<_LegacyTimeZoneDialog> {
  final _zones = BackupTimestamps.zones;
  late String? _selected = _zones.contains(browserTimeZone())
      ? browserTimeZone()
      : null;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      sharedText(
        context,
        'Original backup time zone',
        'Ursprüngliche Backup-Zeitzone',
      ),
    ),
    content: SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sharedText(
              context,
              'This older backup contains times without a time zone. Select the time zone used on the original phone, for example Europe/Berlin. Summer and winter time are calculated for each event. The browser time zone is suggested; confirm it only if it matches the phone.',
              'Diese ältere Sicherung enthält Uhrzeiten ohne Zeitzone. Wähle die Zeitzone des ursprünglichen Handys, z. B. Europe/Berlin. Sommer- und Winterzeit werden für jeden Eintrag berechnet. Die Browser-Zeitzone wird vorgeschlagen; bestätige sie nur, wenn sie zum Handy passt.',
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<String>(
              key: const Key('legacy-backup-time-zone'),
              width: constraints.maxWidth,
              initialSelection: _selected,
              enableFilter: true,
              requestFocusOnTap: true,
              label: Text(
                sharedText(context, 'Source time zone', 'Quell-Zeitzone'),
              ),
              dropdownMenuEntries: [
                for (final zone in _zones)
                  DropdownMenuEntry(value: zone, label: zone),
              ],
              onSelected: (value) => setState(() => _selected = value),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(sharedText(context, 'Cancel', 'Abbrechen')),
      ),
      FilledButton(
        key: const Key('confirm-legacy-time-zone'),
        onPressed: _selected == null
            ? null
            : () => Navigator.pop(context, _selected),
        child: Text(
          sharedText(context, 'Use this time zone', 'Diese Zeitzone verwenden'),
        ),
      ),
    ],
  );
}
