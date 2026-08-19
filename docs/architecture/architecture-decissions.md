# Architecture Decision Records

## ADR-001: Local-first architecture

**Status:** Accepted
**Date:** 2026-08-19

### Context

TerraManager soll zur Verwaltung von Terrarien, Tieren, Fütterungen und später Sensoren eingesetzt werden.

Die Anwendung soll insbesondere im direkten Umfeld der Terrarien zuverlässig funktionieren. Eine permanente Internetverbindung kann dort nicht vorausgesetzt werden.

### Decision

TerraManager wird zunächst als **local-first application** entwickelt.

Die primären Daten werden lokal auf dem jeweiligen Gerät gespeichert. Die Kernfunktionen der Anwendung sollen ohne Internetverbindung funktionieren.

Eine mögliche Cloud-Synchronisation kann zu einem späteren Zeitpunkt ergänzt werden.

### Consequences

**Vorteile:**

* Die Anwendung funktioniert offline.
* QR-Codes können ohne Internetverbindung gescannt werden.
* Änderungen können unmittelbar gespeichert werden.
* Keine Abhängigkeit von einem externen Server für die MVP-Version.
* Datenschutz und Datensouveränität bleiben zunächst vollständig beim Benutzer.

**Nachteile:**

* Daten sind zunächst an das jeweilige Gerät gebunden.
* Eine Synchronisation zwischen mehreren Geräten ist zunächst nicht möglich.
* Backup und Wiederherstellung müssen später berücksichtigt werden.

---

## ADR-002: QR code as stable box identifier

**Status:** Accepted
**Date:** 2026-08-19

### Context

Jede Box soll dauerhaft mit einem QR-Code versehen werden.

Die Daten einer Box können sich im Laufe der Zeit ändern. Beispielsweise können sich Name, Tier, Notizen oder Fütterungsdaten ändern.

Ein bereits angebrachter QR-Code soll deshalb nicht bei jeder Änderung neu erstellt oder gedruckt werden müssen.

### Decision

Der QR-Code enthält ausschließlich eine **dauerhafte eindeutige Kennung der Box**.

Die eigentlichen Box- und Tierdaten werden nicht im QR-Code gespeichert.

Beispiel:

```text
TM:BOX:<UUID>
```

Die UUID wird bei der Erstellung einer Box einmalig generiert und bleibt während der gesamten Lebensdauer der Box unverändert.

Beim Scannen wird die UUID ausgelesen und verwendet, um die zugehörige Box aus der lokalen Datenbank zu laden.

### Consequences

**Vorteile:**

* Der QR-Code muss nach Datenänderungen nicht neu gedruckt werden.
* Der QR-Code bleibt klein und einfach.
* Die Datenstruktur kann unabhängig vom QR-Code erweitert werden.
* Sensible oder umfangreiche Daten werden nicht direkt im QR-Code gespeichert.
* QR-Codes können dauerhaft auf physischen Boxen angebracht werden.

**Nachteile:**

* Ohne Zugriff auf die lokale Datenbank enthält der QR-Code selbst keine Informationen über die Box.
* Bei einem Verlust der lokalen Datenbank kann die QR-ID allein die ursprünglichen Daten nicht wiederherstellen.
