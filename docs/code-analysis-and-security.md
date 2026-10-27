# Statische Code-Analyse & Security Scanning

Diese Dokumentation beschreibt, welche statischen Analysen und Security-Scans in der
CI-Pipeline laufen, wo deren Ergebnisse einsehbar sind und wie mit relevanten
Befunden umgegangen wird.

## Übersicht

| Prüfung | Werkzeug | Was geprüft wird | Wann es läuft | Ergebnis sichtbar in |
|---|---|---|---|---|
| Vulnerability-Scan (semantisch) | GitHub CodeQL | C#- und TypeScript-/JavaScript-Quellcode auf bekannte Schwachstellenmuster (Taint-Analyse) | Push nach `main`/`master`, jeder PR, wöchentlich (Schedule) | GitHub → *Security* → *Code scanning* + PR-Kommentare |
| Qualität & Security | SonarCloud | Bugs, Verwundbarkeiten, Security Hotspots, Code Smells; Quality Gate | Push nach `main`/`master`, PRs (nach Token-Einrichtung) | [sonarcloud.io](https://sonarcloud.io)-Dashboard + PR-Status |
| Abhängigkeits-Scan | Dependabot | Bekannte CVEs in NuGet- und npm-Paketen | Wöchentlich (automatisch) | GitHub → *Security* → *Dependabot* + Update-PRs |

Zusätzlich führt die funktionale CI (`ci.yml`) bei jedem Backend-Commit Unit- und
Integrationstests und beim Frontend die Angular-Tests sowie einen Production-Build
aus – das ist die Grundlage, um Fixes verifizieren zu können.

## 1. GitHub CodeQL (Code Scanning)

Workflow: `.github/workflows/codeql.yml`

- **Sprachen:** C# (Backend) und JavaScript/TypeScript (Frontend), jeweils als
  eigener Analyse-Job.
- **Verfahren:** CodeQL baut eine semantische Datenbank des Codes und spielt
  GitHub's Query-Suiten dagegen. Dabei werden u. a. erkannt:
  - SQL-Injection bzw. unsichere dynamische Queries
  - Path Traversal und Command Injection
  - Cross-Site-Scripting (XSS) im Frontend
  - Schwache Krypto-Algorithmen und unsichere Zufallszahlen
  - Hardgecodete Credentials/Secrets
  - Unsichere Deserialisierung
- **C#-Build:** Die Datenerhebung für C# erfolgt zur Kompilierzeit. Deshalb wird
  die Backend-Solution zwischen `init` und `analyze` explizit gebaut
  (Custom Build mit `build-mode: none`) statt auf Auto-Build zu vertrauen.
- **Wöchentlicher Schedule:** Auch ohne Codeänderung laufen neu veröffentlichte
  Queries gegen den aktuellen Stand.
- **Ergebnisse:** Alerts im GitHub-Security-Tab (*Code scanning*), zusätzlich
  Inline-Annotationen direkt im Pull Request.

> Hinweis: In privaten Repositories muss Code Scanning einmalig unter
> *Settings → Code security* aktiviert sein; öffentliche Repos erhalten es automatisch.

## 2. SonarCloud

Workflow: `.github/workflows/sonarcloud.yml`

- **Was geprüft wird:** Regelsätze für C# und TypeScript – Bugs, Verwundbarkeiten,
  Security Hotspots (z. B. hardgecodete Tokens, schwache Kryptographie) sowie
  Maintainability-Metriken (Code Smells, Duplikate, Komplexität).
- **Quality Gate:** Standard „Sonar way“ – darf keine neuen blockierenden Issues
  einführen, sonst schlägt der Check rot aus und der PR-Status zeigt das an.
- **Scope:** `shorty_backend/shorty_backend` (Testprojekte als `sonar.tests`
  markiert) und `shorty_frontend/src`; automatisch generierte EF-Core-Migrations
  sind ausgeschlossen.
- **Neu-Code-Metriken:** Der Checkout holt die vollständige Historie
  (`fetch-depth: 0`), damit SonarCloud bei PRs nur den neuen Code bewertet.

### Einmaliges Setup (≈ 5 Minuten)

1. Kostenloses Konto unter [sonarcloud.io](https://sonarcloud.io) anlegen und eine
   Organisation erstellen.
2. Token erzeugen: *My Account → Security Tokens*.
3. Token als Repository-Secret `SONAR_TOKEN` hinterlegen
   (*Settings → Secrets and variables → Actions*).
4. Platzhalter in `sonarcloud.yml` ersetzen:
   - `sonar.organization` → eigener Organisations-Key
   - `sonar.projectKey` → frei wählbarer Projekt-Key (das Projekt wird beim
     ersten Scan automatisch angelegt)
5. Pushen – der Job wird durch das vorhandene Secret automatisch aktiv.
   Bis dahin bleibt er dank `if:`-Bedingung inaktiv und lässt die Pipeline grün.

## 3. Dependabot (Abhängigkeits-Scanning)

Konfiguration: `.github/dependabot.yml`

- Prüft **wöchentlich** die NuGet-Pakete (Backend) und npm-Pakete (Frontend) auf
  bekannte Sicherheitslücken (Security Advisories).
- Erzeugt dafür einzelne Update-PRs; Security-Updates haben Vorrang.
- Optional auf reine Security-Updates beschränkt über `security-updates-only: true`.

## Umgang mit Befunden

Folgender Prozess gilt für alle drei Werkzeuge:

1. **Triage:** Jedes neue Finding wird nach Schweregrad (Critical / High / Medium /
   Low) eingeordnet und daraufhin bewertet, ob es ein False Positive ist.
2. **Critical / High:** Sofortiger Fix; der betroffene PR wird nicht gemergt,
   solange der Alert offen ist (CodeQL-Alerts und das SonarCloud-Quality-Gate
   erscheinen direkt im PR und machen den Blocker sofort sichtbar).
3. **Medium / Low:** Im Backlog aufnehmen und zeitnah beheben (nächster Sprint).
4. **False Positives:** Nicht stillschweigend ignorieren, sondern dokumentiert
   ablehnen:
   - CodeQL: Alert dismissen mit Begründung (*Dismiss as fixed* bzw.
     *Mark as approved*).
   - SonarCloud: Issue als *False positive* oder *Won't fix* mit Begründung
     markieren.
   - Ablehnungen werden nach Tool-/Query-Updates erneut auf ihre Rechtfertigung
     hin überprüft.
5. **Abhängigkeiten:** Dependabot-Security-PRs werden schnellstmöglich geprüft und
   gemergt (Regel: gleicher Tag).
6. **Verifikation:** Nach dem Fix muss der zugehörige Pipeline-Lauf bzw. Re-Scan
   grün sein; der Alert schließt sich automatisch, sobald der betroffene Code weg
   oder der Fix eingepflegt ist.
7. **Härtung (optional):** Über Branch-Protection-Regeln können die Status-Checks
   von CodeQL und SonarCloud als *required* vorgeschrieben werden, sodass kein
   Merge ohne bestandenen Scan möglich ist.

### Aktuelle Befunde

| Datum | Werkzeug | Befund | Schweregrad | Status |
|---|---|---|---|---|
| – | – | Noch keine Befunde | – | – |

*(Tabelle bei Auftreten neuer Findings fortlaufend aktualisieren.)*
