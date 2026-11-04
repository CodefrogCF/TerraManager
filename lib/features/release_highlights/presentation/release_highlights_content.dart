import 'package:flutter/material.dart';

/// Release-specific content: edit this numbered list for the next update.
/// Each entry keeps its icon and both translations together. The dialog follows
/// the list order and automatically adapts to the number of entries.
const releaseHighlightsContent = <ReleaseHighlight>[
  ReleaseHighlight(
    number: 1,
    icon: Icons.cleaning_services_outlined,
    de: (
      title: 'Pflegeverlauf für Boxen',
      description: 'Dokumentiere Substratwechsel, Reinigung und Wasserwechsel mit Datum, Uhrzeit und optionalen Notizen. Eigene Pflegearten kannst du direkt im Pflegeverlauf anlegen und verwalten.',
    ),
    en: (
      title: 'Box care history',
      description: 'Record substrate changes, cleaning and water changes with a date, time and optional notes. Create and manage your own care types directly from care history.',
    ),
  ),
  ReleaseHighlight(
    number: 2,
    icon: Icons.tune,
    de: (
      title: 'Eigene Felder für Tiere und Boxen',
      description: 'Ergänze Profile um Text-, Zahlen-, Datums- und Ja/Nein-Felder. Feldvorlagen für Boxen und Tiere verwaltest du beim Bearbeiten. In den Box- und Tierdetails erscheinen nur ausgefüllte, sichtbare Felder.',
    ),
    en: (
      title: 'Custom fields for Animals and Boxes',
      description: 'Add text, number, date and yes/no fields to profiles. Manage Animal and Box field templates when editing. Their details show only populated, visible fields.',
    ),
  ),
  ReleaseHighlight(
    number: 3,
    icon: Icons.picture_as_pdf_outlined,
    de: (
      title: 'Mehr Verlauf auf weniger Seiten',
      description: 'Der vollständige A4-Tierexport nutzt für lange Fütterungs-, Häutungs- und Gewichtsverläufe bis zu drei Spalten. Dadurch passen mehr Einträge auf eine Seite.',
    ),
    en: (
      title: 'More history on fewer pages',
      description: 'Complete A4 Animal reports use up to three columns for long Feeding, Shedding and Weight histories, fitting more entries onto each page.',
    ),
  ),
  ReleaseHighlight(
    number: 4,
    icon: Icons.notifications_active_outlined,
    de: (
      title: 'Verbesserte Fütterungserinnerungen',
      description: 'Fällige Android-Benachrichtigungen bleiben beim Zurückkehren zur laufenden App eingeplant. Android kann die Zustellung weiterhin verzögern.',
    ),
    en: (
      title: 'Improved feeding reminders',
      description: 'Due Android notifications stay scheduled when you return to the running app. Android may still delay delivery.',
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
