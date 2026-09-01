import 'package:flutter/material.dart';

import '../../app_accent.dart';
import '../../app_settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),

          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              key: const Key(
                'theme-mode-selector',
              ),
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: Icon(
                    Icons.settings_brightness,
                  ),
                  label: Text(
                    'System',
                  ),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: Icon(
                    Icons.light_mode,
                  ),
                  label: Text(
                    'Light',
                  ),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: Icon(
                    Icons.dark_mode,
                  ),
                  label: Text(
                    'Dark',
                  ),
                ),
              ],
              selected: {
                settings.themeMode,
              },
              onSelectionChanged: (selection) {
                settings.setThemeMode(
                  selection.first,
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Accent Color',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppAccent.values.map(
              (accent) {
                final selected =
                    accent == settings.accent;

                return ChoiceChip(
                  key: Key(
                    'accent-${accent.name}',
                  ),
                  selected: selected,
                  onSelected: (_) {
                    settings.setAccent(
                      accent,
                    );
                  },
                  avatar: CircleAvatar(
                    backgroundColor: accent.color,
                  ),
                  label: Text(
                    accent.label,
                  ),
                );
              },
            ).toList(),
          ),

          const SizedBox(height: 32),

          Text(
            'Changes are saved automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}