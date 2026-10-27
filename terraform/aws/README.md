# AWS-Deployment (Terraform)

Richtet den kompletten Shorty-Stack in AWS ein (Default: `eu-central-1`):

| Dienst | Zweck |
|---|---|
| EC2 | App-Server (Amazon Linux 2023, Docker): Backend auf :8080, Frontend auf :80 |
| RDS | PostgreSQL-16-Datenbank (`db.t4g.micro`) |
| S3 | Versionierter, verschlüsselter Terraform-Remote-State |
| DynamoDB | State-Locking für parallele Terraform-Läufe |
| CloudWatch | Log Group (Deploy-Log + Container-Logs), CPU-Alarme, Dashboard |
| SNS | Benachrichtigungs-Ziel der CloudWatch-Alarme |
| dazu | VPC, Subnet, Internet Gateway, Security Groups, Elastic IP, IAM-Rollen (OIDC für GitHub Actions, Instance Profile für den CloudWatch-Agent) |

## Einmaliges Bootstrap

1. **Credentials**: AWS CLI installieren und `aws configure` ausführen
   (bzw. die `AWS_*`-Umgebungsvariablen setzen). Das Konto braucht die in
   `iam.tf` beschriebenen Berechtigungen.
2. **Variablen**: `terraform.tfvars.example` nach `terraform.tfvars` kopieren
   und mindestens `db_password` setzen (optional `key_pair_name` für SSH).
3. **Erster Apply mit lokalem State**:
   ```powershell
   terraform init
   terraform apply
   ```
   Erzeugt den kompletten Stack *inklusive* S3-State-Bucket, DynamoDB-Lock-
   Tabelle und der GitHub-Actions-OIDC-Rolle. Der State liegt dabei lokal in
   `terraform.tfstate` (per `.gitignore` geschützt).
4. **State nach S3 migrieren**: Den `backend "s3"`-Block in `provider.tf`
   entkommentieren, dann
   ```powershell
   terraform init -migrate-state
   ```
   (Kopie mit `y` bestätigen). Danach ist die lokale `terraform.tfstate`
   überflüssig – löschen.
5. **Repo-Einstellung**: Settings → *Developer settings* → *OAuth Apps* →
   *GitHub Actions* → **„GenerateIdToken"** (*Advanced workflow uses*)
   aktivieren. Ohne das schlägt der OIDC-Login im Workflow fehl.
6. **Repo-Secrets** (Settings → Secrets and variables → Actions):

   | Secret | Wert |
   |---|---|
   | `AWS_ROLE_ARN` | Ausgabe von `terraform output github_actions_role_arn` |
   | `DB_PASSWORD` | das Passwort aus `terraform.tfvars` |
   | `REPO_TOKEN` | PAT mit Lesezugriff auf das Repo (privat; wird vom EC2 zum Klonen genutzt) |

Danach läuft bei jedem Push nach `main` der Workflow
`.github/workflows/deploy.yml`, der per OIDC plant und appliziert – ohne
gespeicherte AWS-Keys.

## Redeploy nach einer Codeänderung

Die EC2 klont das Repository nur beim ersten Start. Um einen neuen Commit zu
deployen: Actions → **Deploy AWS** → *Run workflow* →
**Redeploy app server = yes**. Das taintet `aws_instance.app`; Terraform
ersetzt die Instanz (der Elastic IP bleibt erhalten, die URL ändert sich
nicht) und `user_data` läuft neu: frischer Clone, Image-Builds, Container
starten. Dauert ca. 15–20 Minuten (RDS-Wartezeit + Builds).

Fortschritt auf der Instanz (SSH, falls Key Pair angehängt):
`tail -f /var/log/shorty-deploy.log`. Container-Logs landen zusätzlich in
CloudWatch Logs unter `/shorty/dev/app`.

## URLs (nach dem Apply)

`terraform output` zeigt:

- `frontend_url` – Angular-Frontend
- `backend_api_url` – REST-API
- `swagger_ui_url` – Swagger UI

## Kosten & Abbau

Laufende Kosten grob 30–40 €/Monat (t3.small + db.t4g.micro; der EIP kostet
nichts, solange er zugewiesen ist). Komplett abbauen:

```powershell
terraform destroy
```

(Damit werden auch S3-Bucket und DynamoDB-Tabelle gelöscht; ein erneutes
Deploy beginnt mit Schritt 3 oben neu.)
