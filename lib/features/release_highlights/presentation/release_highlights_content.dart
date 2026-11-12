import 'package:flutter/material.dart';

/// Release-specific content: edit this numbered list for the next update.
/// Each entry keeps its icon and both translations together. The dialog follows
/// the list order and automatically adapts to the number of entries.
const releaseHighlightsContent = <ReleaseHighlight>[
  ReleaseHighlight(
    number: 1,
    icon: Icons.restaurant_outlined,
    de: (
      title: 'Fütterungen schneller erfassen',
      description:
          'Lege unter „Feldvorlagen verwalten“ ein Feld für die Anzahl und '
          'Auswahllisten etwa für Größe oder Futterart an. Futtervorlagen '
          'füllen die Felder auch bei der Schnellfütterung aus.',
    ),
    en: (
      title: 'Record feedings faster',
      description:
          'Use Manage field templates to add a quantity field and dropdowns '
          'for details like size or food type. Food presets can fill in those '
          'fields in regular and quick feeding forms.',
    ),
  ),
  ReleaseHighlight(
    number: 2,
    icon: Icons.cleaning_services_outlined,
    de: (
      title: 'Pflegeerinnerungen für Boxen',
      description:
          'Lege in der Boxpflege einmalige oder wiederkehrende Termine fest. '
          'Fällige Pflege erkennst du in der Boxübersicht.',
    ),
    en: (
      title: 'Box care reminders',
      description:
          'Set one-time or recurring reminders in Enclosure care. '
          'The Box overview shows which Boxes are due for care.',
    ),
  ),
  ReleaseHighlight(
    number: 3,
    icon: Icons.bedtime_outlined,
    de: (
      title: 'Ruhezeiten für Tiere',
      description:
          'Lege unter „Fütterungserinnerung“ eine Ruhezeit für dein Tier fest. '
          'Fütterungshinweise und Android-Benachrichtigungen pausieren bis '
          'einschließlich Enddatum.',
    ),
    en: (
      title: 'Rest periods for Animals',
      description:
          'Set a rest period in the Animal’s feeding reminder settings. '
          'Feeding alerts and Android notifications pause through the end date.',
    ),
  ),
  ReleaseHighlight(
    number: 4,
    icon: Icons.content_copy_outlined,
    de: (
      title: 'Boxen ohne Namen duplizieren',
      description:
          'Leere beim Duplizieren das Namensfeld, um eine unbenannte Box mit '
          'eigenem QR-Code zu erstellen.',
    ),
    en: (
      title: 'Duplicate a Box without a name',
      description:
          'Clear the name when duplicating a Box to create an unnamed copy '
          'with its own QR code.',
    ),
  ),
];

class ReleaseHighlight {
  const ReleaseHighlight({
    required this.number,
    required this.icon,
    required this.de,
    required this.en,
  }) : assert(number > 0);

  final int number;
  final IconData icon;
  final ({String title, String description}) de;
  final ({String title, String description}) en;

  ({String title, String description}) localized(String languageCode) =>
      languageCode == 'de' ? de : en;
}
