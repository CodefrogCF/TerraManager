---
layout: default
title: TerraManager Datenschutz
---

# TerraManager Datenschutzerklärung

**Gültig ab:** 26. September 2026
**Anwendung:** TerraManager
**Entwickler:** Codefrog
**Datenschutz- und Supportkontakt:** Die aktuellen Kontakt- und Supportmöglichkeiten sind im TerraManager-Projektrepository aufgeführt.

Diese Erklärung gilt für die eigenständige Android-/Webnutzung und den
optionalen, selbst betriebenen Shared-Care-Webmodus. Der Entwickler betreibt
den Shared-Care-Server nicht. Dessen Betreiber verwaltet Zugänge, Speicherung
und Sicherungen.

## 1. Überblick

TerraManager ist eine lokal ausgerichtete Anwendung zur Verwaltung von Terrarientieren und ihren Behausungen.

Datenschutz ist ein zentraler Gestaltungsgrundsatz von TerraManager.

Die aktuelle Version stellt Folgendes weder bereit noch setzt sie es voraus:

* ein vom Entwickler betriebenes TerraManager-Benutzerkonto;
* ein Benutzerprofil;
* ein von TerraManager betriebenes Backend;
* verpflichtenden Cloudspeicher oder eine verpflichtende Synchronisierung;
* Werbung;
* Werbe-IDs;
* Benutzerprofiling;
* von TerraManager betriebene Analysen;
* von TerraManager betriebene Telemetrie;
* Dienste zur Übermittlung von Absturzberichten;
* Abonnementdienste.

Tier- und Sammlungsdaten sollen unter der Kontrolle der Benutzerin oder des Benutzers bleiben.

## 2. Von TerraManager gespeicherte Daten

TerraManager speichert Informationen, die bei der Verwaltung einer Sammlung eingegeben oder erstellt werden.

Abhängig von der Nutzung der Anwendung können dazu gehören:

* Tierdatensätze;
* Tiernamen und Artinformationen;
* Geschlecht sowie Geburts- oder Schlupfinformationen;
* Tiernotizen;
* Tier- und Boxbilder einschließlich Bildhistorien;
* Behausungs- oder Boxdatensätze;
* Maße von Behausungen;
* Behausungs- oder Boxnotizen;
* Zuordnungen zwischen Tieren und Boxen;
* Erstellungs- und Änderungsdaten;
* FeedingEvents und Fütterungsverlauf;
* Gewichts- und Häutungsverläufe von Tieren;
* QR-Kennungen;
* Anwendungseinstellungen.

Diese Informationen sind Anwendungsdaten und werden nicht an einen von TerraManager betriebenen Server übertragen.

## 3. Lokale Speicherung

### Android

Unter Android speichert TerraManager die Sammlungsdatenbank, Anwendungseinstellungen und intern verwaltete Dateien lokal auf dem Endgerät.

Die Android-Produktionsversion fordert die Android-Berechtigung `INTERNET` nicht an.

Dadurch kann die Android-Produktionsanwendung keine üblichen Netzwerkverbindungen verwenden, um TerraManager-Anwendungsdaten an TerraManager, den Entwickler, Werbedienste oder Analysedienste zu übertragen.

TerraManager benötigt für seine üblichen Funktionen zur Sammlungsverwaltung keine Internetverbindung.

### Eigenständige Webanwendung

Bei Verwendung als Webanwendung werden Anwendungsdaten, soweit unterstützt, lokal in der aktiven Browserumgebung gespeichert.

Der Browserspeicher wird durch den Browser und das Betriebssystem verwaltet.

Das Löschen von Browserdaten, die Nutzung privater Browsermodi, das Zurücksetzen des Browserspeichers oder andere Verwaltungsaktionen des Browsers können lokal gespeicherte TerraManager-Daten entfernen.

Die Website oder der Hostinganbieter, über die beziehungsweise den die TerraManager-Webanwendung bereitgestellt wird, kann im Rahmen des üblichen Webhostings technische Verbindungsinformationen wie IP-Adressen, Zeitpunkte von Anfragen oder Browserinformationen verarbeiten.

Diese Verarbeitung auf Hostingebene ist von der Sammlungsverwaltung durch TerraManager getrennt und unterliegt den Datenschutzbestimmungen des jeweiligen Hostinganbieters.

### Shared-Care-Webmodus

Wenn eine Betreiberin oder ein Betreiber Shared Care auf einem Raspberry Pi
oder einem anderen Gerät im lokalen Netz bereitstellt, meldet sich der Browser
über HTTPS an diesem Server an. Daten zu Boxen, Tieren, Fütterungen, Verläufen
und Bildern werden an die SQLite-Datenbank des Betreibers übertragen und dort
gespeichert. Lokale Kontonamen, Passwort-Hashes und Sitzungen liegen in einer
separaten Serverdatenbank. Jeder Browser speichert eigene Einstellungen für
Darstellung, Sprache und Sortierung, aber keine eigene Shared-Care-Sammlungsdatenbank.
Der Betreiber ist für Kontozugänge, Serversicherheit, Zertifikatsvertrauen,
Speicherdauer und Sicherungen verantwortlich. Die Android-App bleibt
eigenständig: Ihr Link in den Einstellungen öffnet Shared Care im Browser,
ohne die lokale Datenbank zu synchronisieren.

Shared Care speichert außerdem ein lokales Änderungsprotokoll für angemeldete
Änderungen an der Sammlung und an Benutzerkonten. Einträge enthalten den
UTC-Zeitpunkt, eine stabile Kennung der ausführenden Person, den Kontonamen und
die Rolle zum damaligen Zeitpunkt, die Aktion, betroffene Datensatzkennungen und
das Ergebnis. Notizen, Bilder, hochgeladene Sicherungen, Passwörter und
Sitzungstoken werden nicht in das Protokoll kopiert. Sammlungsereignisse liegen
in der Sammlungsdatenbank, Kontenereignisse in der Kontendatenbank des Betreibers.
Sie sind nicht Teil portabler `.tmbackup`-Dateien und werden durch eine portable
Wiederherstellung nicht ersetzt. Geschützte Sicherungen des Serververzeichnisses
enthalten diese Einträge.

Der Server entfernt Protokolleinträge, die älter als 365 Tage sind, beim Start
und beim Schreiben neuer Einträge. Eine Deaktivierung oder Löschung des Kontos
entfernt die bisherige Zuordnung im Protokoll innerhalb dieser Frist nicht.
Ältere geschützte Sicherungskopien können frühere Einträge enthalten, bis der
Betreiber diese Kopien löscht. Der Betreiber kontrolliert den Zugriff, informiert
Betreuungspersonen über diese lokale Verarbeitung und ist für den Schutz und
die Löschung von Sicherungen verantwortlich. Protokolldaten werden nicht an den
Entwickler oder einen externen Analysedienst übertragen.

## 4. Datenerhebung und Weitergabe

Der Entwickler betreibt keinen Server und kein Backend, das Tier- oder Sammlungsdaten von Benutzerinnen und Benutzern empfängt. Ein optionaler Shared-Care-Server wird vom Sammlungsbetreiber bereitgestellt.

In den eigenständigen Modi verarbeitet TerraManager Daten zu Tieren, Boxen, FeedingEvents, Bildern und Einstellungen lokal. Im Shared-Care-Modus werden Sammlungsänderungen und Medien an den lokalen Server des Betreibers übertragen; persönliche Darstellungseinstellungen bleiben im Browser.

TerraManager:

* verkauft keine Benutzerdaten;
* verkauft keine Sammlungsdaten;
* verwendet keine Sammlungsdaten für Werbung;
* erstellt keine Werbeprofile;
* gibt keine Sammlungsdaten an Werbetreibende weiter;
* betreibt keine Verhaltensanalyse auf Grundlage von Sammlungsdaten.

In den eigenständigen Modi verlassen Daten die lokale Anwendung nur nach einer ausdrücklich ausgelösten Übertragung oder einem Export. Im Shared-Care-Modus übertragen normale Datensatz- und Bildaktionen Daten zwischen Browser und Betreiber-Server.

Beispiele hierfür sind:

* das Exportieren einer TerraManager-Sicherung;
* das Speichern einer exportierten Datei;
* das Speichern eines QR-Code-Bildes;
* das Speichern ausgewählter QR-Code-Bilder als ZIP-Archiv;
* das Speichern ausgewählter QR-Codes und ihrer Boxbeschriftungen als A4-PDF;
* das Auswählen einer Datei über eine Dateiauswahl des Betriebssystems;
* das Auswählen einer anderen Anwendung oder eines Betriebssystemdienstes als Export- oder Freigabeziel.

Nachdem Daten absichtlich an eine andere Anwendung, einen Speicheranbieter, eine Betriebssystemkomponente oder ein anderes Drittanbieterziel übergeben wurden, kann dieser Dienst die Daten nach seinen eigenen Datenschutzbestimmungen verarbeiten.

TerraManager kontrolliert keine von der Benutzerin oder dem Benutzer ausgewählten Anwendungen oder Dienste Dritter.

## 5. Sicherungen

TerraManager ermöglicht Sicherungen der eigenständig gespeicherten lokalen Daten oder, für Shared-Care-Administratoren, der vom Betreiber gehosteten Sammlung.

Sicherungen werden nur infolge einer von der Benutzerin oder dem Benutzer ausgelösten Aktion erstellt.

TerraManager lädt Sicherungen nicht automatisch auf einen TerraManager-Server oder in einen Clouddienst hoch.

Im Shared-Care-Modus können Administratoren eine portable Sammlungssicherung
ausdrücklich herunterladen oder wiederherstellen. Der Betreiber sollte
zusätzlich das Serververzeichnis sichern, damit Sammlung und Kontodatenbanken
geschützt sind. Portable Sicherungen enthalten keine Konten, Sitzungen oder
persönlichen Browsereinstellungen. TerraManager verschlüsselt keine dieser
Sicherungen; der Betreiber schützt Speicherort und Zugriff.

Die Benutzerin oder der Benutzer wählt aus, wo eine exportierte Sicherung gespeichert oder wohin sie übertragen wird.

TerraManager verschlüsselt Sicherungsarchive nicht. Personen, die Zugriff auf eine exportierte Sicherung erhalten, können möglicherweise die darin enthaltenen Sammlungsdaten und Medien lesen.

Sicherungsdateien sollten deshalb nur über angemessen geschützte Speicher- und Übertragungswege gespeichert und übertragen werden.

Benutzerinnen und Benutzer sind für den Schutz der von ihnen erstellten Sicherungsdateien einschließlich aller außerhalb von TerraManager gespeicherten Kopien verantwortlich.

Eine Sicherung kann in TerraManager gespeicherte Sammlungsinformationen enthalten und sollte entsprechend der Vertraulichkeit der eingegebenen Informationen behandelt werden.

## 6. Bilder

TerraManager ermöglicht es, Tier- und Boxdatensätzen Bilder und lokale
Bildhistorien zuzuordnen.

Im eigenständigen Modus werden für TerraManager ausgewählte oder erstellte Bilder verarbeitet und als Teil der lokal verwalteten Daten gespeichert.

TerraManager lädt Tier- oder Boxbilder nicht automatisch auf einen
TerraManager-Server hoch.

Im Shared-Care-Modus werden für Datensätze ausgewählte Bilder im Rahmen der
ausgelösten Aktion an den lokalen Server des Betreibers übertragen.

Wenn Daten mit Bildern exportiert, freigegeben oder gesichert werden, können diese Dateien durch das von der Benutzerin oder dem Benutzer ausgewählte Ziel verarbeitet werden.

## 7. QR-Codes und Kamerazugriff

TerraManager verwendet QR-Codes, um physische Behausungen mit Boxdatensätzen in der Anwendung zu verknüpfen.

Unter Android fordert TerraManager den Kamerazugriff für das Scannen von QR-Codes und gegebenenfalls für von der Benutzerin oder dem Benutzer ausgelöste Kamerafunktionen an.

Die QR-Code-Erkennung erfolgt auf dem Endgerät.

Einzelne QR-Bilder, ZIP-Archive und A4-PDF-Bögen werden vollständig auf dem Endgerät erzeugt. TerraManager lädt bei der Erstellung dieser Dateien weder QR-Kennungen noch Boxbeschriftungen hoch.

ZIP- und PDF-Exporte werden erst gespeichert, nachdem die Benutzerin oder der Benutzer über den Speicherdialog des Betriebssystems ein Ziel ausgewählt hat. Dieser benutzergesteuerte Dateizugriff erfordert keine zusätzliche weitreichende Speicher-, Medien- oder Netzwerkberechtigung für TerraManager.

TerraManager überträgt weder Kamerabilder noch decodierte TerraManager-QR-Inhalte an einen von TerraManager betriebenen Server.

Im Shared-Care-Modus erkennt der Browser Box-QR-Codes lokal. Bei einem gültigen
TerraManager-Boxcode sendet er nur die decodierte QR-Kennung an den Server
desselben Betreibers, um die Box zu finden. Kamerabilder werden nicht
hochgeladen. Der Scanner verwendet die integrierte QR-Erkennung des Browsers
und lädt keinen Decoder von einem öffentlichen CDN. Die Kameraberechtigung
fragt der Browser erst beim Öffnen des Scanners an. Für den Kamerazugriff
auf anderen Geräten im lokalen Netz ist eine vertrauenswürdige HTTPS-Adresse
erforderlich.

Kamerazugriff wird nur angefordert, wenn eine kamerabasierte Funktion verwendet wird oder das Betriebssystem die Berechtigung für diese Funktion verlangt.

Die Kameraberechtigung kann in den Android-Systemeinstellungen verwaltet werden.

## 8. Android-Berechtigungen

Die Android-Produktionsversion ist so gestaltet, dass sie nur für die Anwendungsfunktionen erforderliche Berechtigungen anfordert.

Das aktuelle Produktionspaket kann die folgenden Berechtigungen deklarieren:

### Kamera

`android.permission.CAMERA`

Wird zum Scannen von QR-Codes und für von der Benutzerin oder dem Benutzer ausgelöste Kamerafunktionen verwendet.

### Schreibzugriff auf externen Speicher älterer Android-Versionen

`android.permission.WRITE_EXTERNAL_STORAGE`

Diese Berechtigung wird mit

`maxSdkVersion="28"`

deklariert.

Sie gilt daher nur für Android 9 / API-Level 28 und ältere Versionen.

Sie dient der Kompatibilität von Dateiexporten mit älteren unterstützten Android-Versionen.

Für Android 10 und neuere Versionen gilt sie nicht.

### Interne Android-Kompatibilitätsberechtigungen

Android- oder AndroidX-Bibliotheken können anwendungsspezifische interne Berechtigungen hinzufügen, mit denen Android-Komponenten sicher verwaltet werden.

Das Produktionspaket kann beispielsweise eine anwendungsspezifische `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` enthalten.

Solche Berechtigungen geben TerraManager keinen Zugriff auf persönliche Benutzerdaten.

## 9. Von der Android-Produktionsversion nicht angeforderte Berechtigungen

Die aktuelle Android-Produktionsversion fordert Folgendes nicht an:

* Internetzugriff;
* Zugriff auf den Netzwerkstatus;
* Standortzugriff;
* Zugriff auf Kontakte;
* Mikrofonzugriff;
* Zugriff auf Android-Benutzerkonten;
* Systemberechtigung für Benachrichtigungen;
* uneingeschränkten Lesezugriff auf externen Speicher.

Einige von der Benutzerin oder dem Benutzer ausgewählte Android-Systemkomponenten, Datei- oder Medienauswahlen können vorübergehenden Zugriff auf einzelne Dateien gewähren, ohne TerraManager weitreichende Speicherberechtigungen zu erteilen.

## 10. Technik zum Scannen von QR-Codes

TerraManager verwendet Open-Source-Komponenten Dritter zum Scannen von QR-Codes und für weitere Anwendungsfunktionen.

Die QR-Erkennung erfolgt in der Android-Anwendung lokal auf dem Endgerät.

Die Android-Produktionsversion fordert keinen Internetzugriff an. Der Android-Anwendungsprozess von TerraManager verwendet daher keine üblichen Netzwerkverbindungen, um beim QR-Scannen QR-Bilder, decodierte QR-Inhalte oder Sammlungsinformationen zu übertragen.

Komponenten Dritter unterliegen weiterhin ihren jeweiligen Softwarelizenzen.

## 11. Fütterungserinnerungen

TerraManager kann fütterungsbezogene Erinnerungsinformationen innerhalb der Anwendung anzeigen.

Die aktuelle Version benötigt für diese Funktion keine Android-Systemberechtigung für Benachrichtigungen.

Im eigenständigen Modus werden Fütterungserinnerungen anhand lokaler Daten berechnet. Im Shared-Care-Modus berechnet der Betreiber-Server die Erinnerungstermine aus den gemeinsamen Datensätzen; der Browser zeigt sie an und markiert fällige Erinnerungen.

## 12. Konten und Registrierung

Die eigenständige TerraManager-Anwendung verlangt keine Registrierung eines Benutzerkontos.

Für die eigenständige Nutzung sind kein TerraManager-Benutzername, kein Passwort und kein Online-Benutzerprofil erforderlich. Shared Care verlangt ein lokales Konto, das der Serverbetreiber anlegt.

Der Entwickler betreibt kein Backend für Benutzerkonten. Shared Care verwendet lokale Konten auf dem Server des Betreibers; dessen Kontodatenbank ist von der Sammlungsdatenbank getrennt.

## 13. Keine Werbung

TerraManager enthält keine Werbung.

Es bindet keine Werbenetzwerke ein, um zielgerichtete oder nicht zielgerichtete Werbung anzuzeigen.

Sammlungsdaten werden nicht zur Erstellung von Werbeprofilen verwendet.

## 14. Keine TerraManager-Analysen oder Nachverfolgung

TerraManager betreibt kein Analyse- oder Benutzertracking-System.

Der Entwickler erhält keine Nutzungsverläufe darüber, wie Benutzerinnen und Benutzer durch ihre Sammlungen navigieren, welche Tiere sie verwalten, wann sie Fütterungen erfassen oder welche Informationen sie eingeben.

Die Android-Produktionsversion fordert keinen Internetzugriff an.

## 15. Speicherdauer

Lokal gespeicherte TerraManager-Daten verbleiben auf dem Endgerät oder in der jeweiligen Browserumgebung, bis sie durch die Benutzerin oder den Benutzer, das Betriebssystem, den Browser oder durch Maßnahmen der Anwendungsverwaltung entfernt werden.

Shared-Care-Sammlungsdaten verbleiben auf dem Server des Betreibers, bis sie
durch Berechtigte geändert, gelöscht oder wiederhergestellt oder durch den
Betreiber entfernt werden. Das Löschen von Daten eines einzelnen Browsers
löscht die gemeinsame Serversammlung nicht.

Abhängig von der Plattform können Daten beispielsweise durch folgende Aktionen entfernt werden:

* Löschen von Datensätzen in TerraManager;
* Löschen der Anwendungsdaten;
* Löschen des Browserspeichers;
* Deinstallieren der Anwendung;
* Löschen exportierter Sicherungsdateien;
* Löschen exportierter Bilder oder Dokumente.

Durch die Deinstallation von TerraManager werden Sicherungsdateien oder andere Dateien, die zuvor an Orte außerhalb des privaten Anwendungsspeichers exportiert wurden, nicht unbedingt gelöscht.

Diese exportierten Dateien müssen separat entfernt werden.

## 16. Datenübertragung auf ein anderes Gerät

TerraManager unterstützt die Übertragung von Sammlungsdaten zwischen Geräten über die Sicherungs- und Wiederherstellungsfunktion.

Die Übertragung wird durch die Benutzerin oder den Benutzer ausgelöst und gesteuert.

TerraManager betreibt für diesen Vorgang keinen zwischengeschalteten Synchronisierungsserver.

Shared Care ist ein eigener, vom Betreiber bereitgestellter Modus, in dem
angemeldete Browser eine gemeinsame Serverdatenbank verwenden. Er
synchronisiert sich nicht mit eigenständigen Android- oder Websammlungen;
für die Übernahme ist ein ausdrücklicher Backup-Import nötig.

Die Benutzerin oder der Benutzer ist dafür verantwortlich, eine geeignete und sichere Methode zur Übertragung der Sicherungsdatei zwischen Geräten auszuwählen.

## 17. Von Benutzerinnen und Benutzern eingegebene persönliche Informationen

TerraManager ist zur Verwaltung von Tieren und Behausungen und nicht von persönlichen Profilen vorgesehen.

Freitextfelder wie Tier- und Boxnotizen ermöglichen technisch jedoch die Eingabe beliebiger Informationen.

Benutzerinnen und Benutzer sollten keine persönlichen oder sensiblen Informationen eingeben, die für die Verwaltung ihrer Sammlung nicht erforderlich sind.

Freiwillig eingegebene Informationen werden wie andere Sammlungsdaten behandelt: Im eigenständigen Modus bleiben sie lokal, im Shared-Care-Modus liegen sie auf dem Server des Betreibers.

## 18. Software Dritter

TerraManager verwendet Bibliotheken und Plattformkomponenten Dritter für Funktionen wie:

* lokale Datenbankspeicherung;
* Kamera- und Bildauswahl;
* Erzeugung und Scannen von QR-Codes;
* lokale Erzeugung von ZIP- und PDF-Dateien;
* Bildverarbeitung;
* Dateiauswahl und -speicherung;
* Erstellung und Extraktion von Sicherungen.

Die Einbindung einer Softwarebibliothek bedeutet nicht, dass TerraManager dieser Bibliothek Sammlungsdaten über ein Netzwerk bereitstellt.

Unter Android fordert die Produktionsanwendung die Berechtigung `INTERNET` nicht an.

Softwarelizenzen und Hinweise zu Komponenten Dritter sind in den Abhängigkeitsinformationen des Projekts und den jeweiligen Open-Source-Lizenzhinweisen verfügbar.

## 19. Betriebssystem- und Drittanbieterdienste

Einige Aktionen übergeben Daten absichtlich an Dienste, die durch das Betriebssystem oder die Benutzerin beziehungsweise den Benutzer ausgewählt und kontrolliert werden.

Beispiele hierfür sind:

* die Android-Fotoauswahl;
* die Android-Dateiauswahl;
* ein Speicherdialog des Betriebssystems;
* eine Dateiverwaltung;
* eine Galerieanwendung;
* eine ausdrücklich ausgewählte Cloudspeicheranwendung;
* eine andere als Exportziel ausgewählte Anwendung.

Diese Anwendungen und Dienste arbeiten unabhängig von TerraManager.

Ihre Verarbeitung von Dateien oder anderen Informationen richtet sich nach ihren eigenen Datenschutzbestimmungen und Einstellungen.

## 20. Sicherheit

Die eigenständige Anwendung speichert Daten lokal. Shared Care hält die Sammlung auf dem Server des Betreibers im lokalen Netz; dieser muss Host, HTTPS-Schlüssel und Sicherungen schützen.

Lokale Speicherung beseitigt jedoch nicht alle Sicherheitsrisiken.

Personen mit ausreichendem Zugriff auf ein entsperrtes Gerät, eine exportierte Sicherung oder andere exportierte TerraManager-Dateien können möglicherweise auf darin enthaltene Informationen zugreifen.

Benutzerinnen und Benutzer sollten ihre Geräte und exportierten Sicherungen deshalb mit geeigneten Sicherheitsmaßnahmen des Betriebssystems schützen.

## 21. Änderungen dieser Datenschutzerklärung

Diese Datenschutzerklärung kann aktualisiert werden, wenn sich die Funktionen, unterstützten Plattformen oder die Datenverarbeitung von TerraManager ändern.

Wesentliche Änderungen an Datenerhebung, Datenweitergabe, Netzwerkfunktionen, Konten, Analysen, Werbung oder Cloudfunktionen werden in einer aktualisierten Fassung dieses Dokuments berücksichtigt.

Das oben angegebene Gültigkeitsdatum zeigt, seit wann die aktuelle Fassung gilt.

## 22. Kontakt

Fragen zum Datenschutzverhalten von TerraManager können über die aktuellen Supportkanäle gestellt werden:

[TerraManager-Support](https://github.com/CodefrogCF/TerraManager/blob/main/SUPPORT.md)

Wird TerraManager über einen App-Store vertrieben, kann außerdem der aktuelle Entwickler- oder Supportkontakt im jeweiligen Storeeintrag verwendet werden.
