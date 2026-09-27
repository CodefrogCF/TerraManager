import 'package:flutter/material.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/l10n/app_localizations_labels.dart';
import 'package:terramanager/shared_client/administration/accounts/presentation/pages/shared_accounts_section.dart';
import 'package:terramanager/shared_client/administration/audit/presentation/pages/shared_audit_section.dart';
import 'package:terramanager/shared_client/backups/presentation/widgets/shared_backup_section.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_qr_export.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

class SharedSettingsPage extends StatelessWidget {
  const SharedSettingsPage({
    super.key,
    required this.api,
    required this.username,
    required this.role,
    required this.connected,
    required this.actionsEnabled,
    required this.onLogout,
    required this.onRestored,
    this.onBackupBusyChanged,
  });

  final SharedApiClient api;
  final String username;
  final String role;
  final bool connected;
  final bool actionsEnabled;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRestored;
  final ValueChanged<bool>? onBackupBusyChanged;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return ConstrainedPageWidth(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.l10n.appearance,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.theme,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              key: const Key('shared-theme-mode-selector'),
              segments: [
                for (final value in ThemeMode.values)
                  ButtonSegment<ThemeMode>(
                    value: value,
                    icon: Icon(switch (value) {
                      ThemeMode.system => Icons.settings_brightness,
                      ThemeMode.light => Icons.light_mode,
                      ThemeMode.dark => Icons.dark_mode,
                    }),
                    label: Text(context.l10n.themeModeLabel(value)),
                  ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) =>
                  settings.setThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            context.l10n.accentColor,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppAccent>(
                key: const Key('shared-accent-color-selector'),
                value: settings.accent,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                items: [
                  for (final accent in AppAccent.values)
                    DropdownMenuItem<AppAccent>(
                      value: accent,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: accent.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(context.l10n.appAccentLabel(accent)),
                        ],
                      ),
                    ),
                ],
                onChanged: (accent) {
                  if (accent != null) settings.setAccent(accent);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('next-feeding-summary-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.nextFeedingSummary),
            subtitle: Text(context.l10n.nextFeedingSummaryDescription),
            value: settings.nextFeedingSummaryEnabled,
            onChanged: settings.setNextFeedingSummaryEnabled,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('big-picture-mode-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.bigPictureMode),
            subtitle: Text(context.l10n.bigPictureModeDescription),
            value: settings.bigPictureModeEnabled,
            onChanged: settings.setBigPictureModeEnabled,
          ),
          const SizedBox(height: 32),
          Text(
            context.l10n.animalNameOrder,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.animalNameOrderDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AnimalNameOrder>(
              key: const Key('shared-animal-name-order-selector'),
              showSelectedIcon: false,
              segments: [
                for (final order in AnimalNameOrder.values)
                  ButtonSegment<AnimalNameOrder>(
                    value: order,
                    label: Text(context.l10n.animalNameOrderLabel(order)),
                  ),
              ],
              selected: {settings.animalNameOrder},
              onSelectionChanged: (selection) =>
                  settings.setAnimalNameOrder(selection.first),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            context.l10n.language,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppLanguage>(
              key: const Key('shared-language-selector'),
              segments: [
                for (final value in AppLanguage.values)
                  ButtonSegment<AppLanguage>(
                    value: value,
                    label: Text(context.l10n.appLanguageLabel(value)),
                  ),
              ],
              selected: {settings.language},
              onSelectionChanged: (selection) =>
                  settings.setLanguage(selection.first),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            context.l10n.changesSavedAutomatically,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 24),
          SharedBoxQrExportSection(api: api, enabled: actionsEnabled),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Text(
            sharedText(context, 'Shared server', 'Gemeinsamer Server'),
            key: const Key('shared-server-section-heading'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            sharedText(
              context,
              'Collection data is stored on the server. The settings above belong to this browser.',
              'Sammlungsdaten liegen auf dem Server. Die Einstellungen darüber gelten nur für diesen Browser.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ListTile(
            key: const Key('shared-server-status'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              connected ? Icons.dns_outlined : Icons.cloud_off_outlined,
            ),
            title: Text(api.origin.origin),
            subtitle: Text(
              '$username · ${role == 'administrator' ? sharedText(context, 'Administrator', 'Administrator') : sharedText(context, 'Caregiver', 'Betreuung')} · ${connected ? sharedText(context, 'Connected', 'Verbunden') : sharedText(context, 'Offline', 'Offline')}',
            ),
          ),
          if (role == 'administrator') ...[
            const SizedBox(height: 24),
            Text(
              context.l10n.backupAndRestore,
              key: const Key('shared-backup-section-heading'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              sharedText(
                context,
                'Only administrators can export or replace the shared collection.',
                'Nur Administratoren können die gemeinsame Sammlung sichern oder ersetzen.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SharedBackupSection(
              api: api,
              connected: actionsEnabled,
              onRestored: onRestored,
              onBackupBusyChanged: onBackupBusyChanged,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            SharedAccountsSection(api: api),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            SharedAuditSection(api: api, enabled: actionsEnabled),
          ],
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            key: const Key('shared-sign-out-button'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(sharedText(context, 'Sign out', 'Abmelden')),
            trailing: const Icon(Icons.chevron_right),
            onTap: onLogout,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
