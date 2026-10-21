# Issue #230: Gerätetests nach der automatisierten Messreihe

Status: **Namensänderung ohne Neuladen, Rückkehr aus dem Hintergrund,
Wiederverbindung, zwei Tabs, Konflikthinweis, Verhalten ohne Verbindung,
Kontosperre sowie abgelehnte und erfolgreiche Wiederherstellung am 19.10.2026
vom Nutzer bestätigt.** Nach dem simulierten
Verbindungsabbruch wurde das Update nach ungefähr zehn Sekunden ohne Neuladen
sichtbar. Am 21.10.2026 wurden auch der automatische Sitzungsablauf nach zwölf
Stunden, die erneute Anmeldung und anschließende automatische Aktualisierungen
bestätigt. Die automatisierten Läufe sind beendet. Testadresse:
`https://192.168.1.117:8443`. Die Produktionsadresse an Port 443 gehört nicht zu
diesen Tests. Das englische [Prüfprotokoll](shared-care-integrated-physical-checks.md)
enthält die technischen Anforderungen und den Ergebnisstand.

Der [erfasste Nutzerbericht](data/shared-care-integrated-physical-2026-10-19.json)
bestätigt die durchgeführten Funktionstests. Die zehn Sekunden sind eine
Nutzerschätzung für die Wiederverbindung, keine gemessene p95-Latenz. Kontosperre
und beide Wiederherstellungsfälle wurden zusammenfassend als erwartungsgemäß
bestätigt; genaue Meldungstexte und getrennte Angaben zu Neuladen/Anmeldung wurden
nicht geliefert.

**HTTPS:** S25/Brave und Windows Chrome/Firefox/Edge wurden ohne Warnung gemeldet.
S22/Firefox verwendete eine übergangene Zertifikatwarnung; die lokale CA fehlt.
Auf ausdrücklichen Wunsch des Nutzers bleibt der S22 vorerst aus der Prüfung mit
vertrauenswürdigem HTTPS ausgenommen. Es wurde kein Android-Zertifikat installiert
und keine Firefox-Vertrauenseinstellung geändert. Seine früheren Funktionstests
bleiben mit dieser Einschränkung erfasst. Die Wiederherstellung wurde anschließend
nur mit den vier ohne Warnung gemeldeten Clients angefragt und bestätigt.

Die Sitzung aus der Anmeldung vom 20.10.2026 um 21:19 Uhr endete laut Nutzer
nach zwölf Stunden automatisch. Trotz einer Bearbeitung kurz zuvor erschien
ohne manuelles Neuladen der Anmeldebildschirm. Die anschließende Anmeldung und
automatische Aktualisierung von einem anderen Client wurden ebenfalls bestätigt.
Der genaue Umschaltzeitpunkt wurde nicht gemessen.
Die Ressourcenbudgets wurden am 19.10.2026 ausdrücklich angenommen und im ADR
festgehalten: Caddy bei Änderungen bis fünf Clients höchstens 0,25 %, bei zehn
Clients höchstens 0,30 % eines CPU-Kerns; die übrigen Grenzen bleiben bestehen.
Damit sind die vorgesehenen Prüfungen für #230 abgeschlossen. Der
[Abschlussbericht](shared-care-integrated-acceptance-2026-10-21.md) fasst die
Nachweise zusammen. Die HTTPS-Ausnahme des S22 bleibt wie vereinbart dokumentiert.

## Vorbereitung

1. Für jeden Browser ein privates Fenster oder ein eigenes Testprofil verwenden.
   Test und Produktion verwenden auf derselben IP denselben Sitzungscookie;
   verschiedene Ports trennen diesen Cookie nicht.
2. Für die Prüfung mit vertrauenswürdigem HTTPS muss die Adresse ohne
   Zertifikatwarnung funktionieren. S22/Firefox ist auf Nutzerwunsch vorerst
   ausgenommen. Keine Zertifikatinstallation oder neue Vertrauenseinstellung
   ist Teil der weiteren Schritte.
3. Die privaten Zugangsdaten stehen in der lokal kopierten `credentials.json`.
   Das oberste Zugangspaar ist der Testadministrator; unter `clients` stehen
   drei Pflegezugänge. Passwörter und den Dateiinhalt nicht ins Ergebnisprotokoll
   oder nach GitHub kopieren.
4. Als fünf gleichzeitige Clients verwenden:

   | Client | Browser | Testzugang |
   | --- | --- | --- |
   | Galaxy S25 Ultra | Brave | erster Pflegezugang |
   | Galaxy S22 | Firefox | zweiter Pflegezugang; frühere Funktionstests mit Zertifikatsausnahme, jetzt ausgenommen |
   | Windows | Chrome | Testadministrator |
   | Windows | Firefox | dritter Pflegezugang |
   | Windows | Edge | erster Pflegezugang |

   Ein drittes Android-Gerät ist für diese Gruppe nicht erforderlich. Für die
   Browserabdeckung wurden die zusätzlichen Kombinationen bisher nicht
   durchgeführt. S22/Firefox bleibt auf Nutzerwunsch aus der weiteren Prüfung
   mit vertrauenswürdigem HTTPS ausgenommen. Weitere Browser sind keine
   Voraussetzung für die bereits bestätigten vier übrigen Clients.

## Runde A: Aktualisierung, Hintergrund und Verbindung

1. **Aktualisierung:** Auf allen Clients dasselbe Testtier öffnen, dessen Name
   mit `Evaluation Animal 1` beginnt. Einige Clients in der Tierliste lassen,
   andere in den Details. Im Windows-Chrome den Namen auf `TM230-G1` ändern und
   speichern. Auf allen übrigen Clients muss der neue Name ohne Neuladen
   erscheinen. Mit `TM230-G2` wiederholen. Fokusverlust, doppelte Einträge,
   unerwartete Seitenwechsel oder veraltete Werte notieren.
2. **Hintergrund:** Auf einem Handy die Seite geöffnet lassen, eine Minute zu
   einer anderen App wechseln oder den Bildschirm sperren. Inzwischen am Laptop
   auf `TM230-H1` ändern. Zurückkehren: Der aktuelle Wert muss erscheinen und die
   Seite bedienbar sein. Auf beiden Handys in Firefox und Brave wiederholen.
   Notieren, ob der Browser die Seite vollständig neu geladen hat.
3. **Verbindungsunterbrechung:** Auf nur einem Handy die Verbindung zum Pi für
   eine Minute unterbrechen. Dabei auch eine mögliche Mobilfunkverbindung
   berücksichtigen. Am verbundenen Laptop auf `TM230-N1` ändern. Verbindung am
   Handy wiederherstellen: Der aktuelle Wert muss ohne manuelles Neuladen
   erscheinen. Verbindungsanzeige und ungefähre Erholungszeit notieren.

Die menschlich beobachtete Zeit dient der Funktionsprüfung. Die automatisierte
Messreihe liefert die p95-Latenzen; eine Stoppuhr ersetzt diese Verteilung nicht.

## Runde B: Mehrere Tabs, Entwurf und Konflikt

1. Im selben Laptopbrowser zwei Testtabs öffnen: einer in der Liste, einer in
   den Details. Eine Änderung aus einem anderen Browser muss beide erreichen.
2. Einen ungespeicherten Namensentwurf öffnen. Aus einem anderen Browser
   denselben Datensatz ändern und speichern. Der erste Entwurf muss erhalten
   bleiben; beim anschließenden Speichern muss der Konflikt erkennbar behandelt
   werden. Einen abgelehnten Speichervorgang nicht als Erfolg werten.
3. Einen Entwurf bei kurz unterbrochener Verbindung behalten und nach der
   Wiederverbindung prüfen. Ein Speicherversuch ohne Serverbestätigung darf
   nicht als erfolgreich bestätigt werden.

## Runde C: Sitzung und Wiederherstellung

Diese Fälle erst nach Runde A/B getrennt durchführen und protokollieren. Sie
verändern den gemeinsamen Testzustand. Ausschließlich die Wegwerfdaten an
Port 8443 und die Testkonten verwenden.

- **Kontosperre:** Einen Pflegezugang vom Testadministrator deaktivieren,
  während dessen Seite in einem anderen Browser geöffnet ist. Erwartet werden
  ein erkennbarer Anmeldebedarf, keine weiteren geschützten Aktualisierungen
  und eine nutzbare Anmeldung. Den Testzugang danach wieder aktivieren.
- **Natürlicher Sitzungsablauf:** Die aktuelle Serversitzung läuft zwölf Stunden
  nach der Anmeldung ab (`AccountStore.sessionLifetime`). Anmeldezeit und
  Browser notieren, den Testtab erhalten und nach dem tatsächlichen Ablauf
  prüfen. Eine manuelle Abmeldung oder Kontosperre zählt nicht als natürlicher
  Ablauf. Wird der Tab vom Betriebssystem verworfen, dies gesondert notieren.
- **Abgelehnte Wiederherstellung durch den Server:** Im Firefox den Namen auf
  `TM230-RESTORE-A` setzen. Im Administrator-Chrome unter Einstellungen eine
  gemeinsame Sicherung **A** exportieren und speichern. Den Chrome dabei in den
  Einstellungen lassen. Im Firefox den Namen auf `TM230-RESTORE-B` ändern.
  Im Chrome nun die gültige Datei **A** zur Wiederherstellung wählen und die
  Rückfrage bestätigen. Der Server muss die inzwischen veraltete Sicherheitskopie
  ablehnen (`safety_backup_stale` / neue Sicherheitskopie erforderlich); der Name
  muss **B** bleiben. Ein auf einem anderen Client geöffneter Entwurf muss
  erhalten bleiben. Diese Prüfung verwendet eine gültige Datei und erreicht die
  Serverprüfung, statt nur eine beschädigte Datei lokal abzulehnen.
- **Erfolgreiche Wiederherstellung:** Nach dem abgelehnten Versuch im selben
  Administrator-Chrome eine neue aktuelle Sicherheitskopie **B** exportieren und
  speichern. Danach dort direkt die frühere Datei **A** wiederherstellen, während
  die anderen Clients keine Änderungen speichern. Chrome in den Einstellungen
  lassen, damit der neu erhaltene Sicherheitsnachweis erhalten bleibt. Die
  beobachtenden Clients mit geschlossenen Bearbeitungsdialogen müssen wieder
  `TM230-RESTORE-A` anzeigen. Einen gegebenenfalls erforderlichen erneuten Login
  oder manuelles Neuladen notieren.
  Für den Sitzungsablauf einen von dieser Wiederherstellung getrennten Lauf
  verwenden, da eine Wiederherstellung den Sitzungszustand beeinflussen kann.

## Ergebnis zum Kopieren

```text
Datum/Uhrzeit:
Gerät / Browser / Version:
HTTPS ohne Warnung: ja / nein
Geprüfte Fälle:
Aktualisierung in Liste und Details:
Hintergrund / Rückkehr:
Verbindungsunterbrechung / Erholung:
Mehrere Tabs:
Entwurf / Konflikt:
Kontosperre / natürlicher Ablauf (getrennt):
Abgelehnte / erfolgreiche Wiederherstellung (getrennt):
Manuelles Neuladen erforderlich:
Fehler oder Auffälligkeiten:
Nicht geprüft:
```

Fehlende Beobachtungen bleiben als „nicht geprüft“ stehen. Screenshots vor dem
Teilen auf Zugangsdaten und persönliche Inhalte prüfen. Das Protokoll benötigt
weder Passwörter noch Cookies oder vollständige Netzwerkaufzeichnungen.
