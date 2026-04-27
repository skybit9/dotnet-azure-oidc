# .NET 10 → Azure App Service via OIDC + Terraform

Zero static secrets. OIDC federated identity. IaC-managed infra. Multi-environment deployment.

---

## Architecture

```
GitHub Actions (deploy job)
  │
  │  mint OIDC JWT (repo:skybit9/dotnet-azure-oidc:environment:dev|production)
  ▼
GitHub OIDC Provider
  │
  │  token exchange
  ▼
Azure AD (validates subject claim against federated credential)
  │
  │  short-lived access token (~15 min)
  ▼
User-Assigned Managed Identity
  │
  │  Contributor role (subscription scope)
  ▼
Azure Linux Web App (.NET 10, B1)
```

---

## Branch Strategy

```
dev branch  →  push  →  build + test ONLY (CI gate, no deploy)
     │
     │  Pull Request to main (Build and Test must pass)
     ▼
main branch →  merge →  build + test + deploy
                              │
                              ├── deploy to dev subscription (environment: dev)
                              └── deploy to prod subscription (environment: production)
```

---

## Environments

| Environment | Azure Subscription | Web App | GitHub Environment |
|-------------|-------------------|---------|-------------------|
| dev | dev | my-dotnet-app-dev | dev |
| prod | prod | my-dotnet-app-prod | production |

---

## First-Time Setup (run once per environment)

### 1. Bootstrap Terraform state storage

```bash
chmod +x bootstrap.sh
# For dev:
az account set --subscription "dev"
./bootstrap.sh

# For prod:
az account set --subscription "prod"
./bootstrap.sh
```

Copy each printed `storage_account_name` into the respective backend block in `main.tf`.

### 2. Configure terraform.tfvars

```bash
# For dev:
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit with dev values

# For prod:
cp infra/terraform.tfvars.example infra/terraform.tfvars.prod
# Edit with prod values
```

Add both to `.gitignore` — never commit real values.

### 3. Apply Terraform per environment

```bash
cd infra

# Dev:
az account set --subscription "dev"
terraform init
terraform apply

# Prod (separate state):
az account set --subscription "prod"
terraform init -backend-config="storage_account_name=PROD_SA_NAME" -reconfigure
terraform apply -var-file="terraform.tfvars.prod"
```

### 4. Set GitHub Secrets

Settings → Secrets and variables → Actions

**Repository-level (used by both environments):**
None needed — all secrets are environment-scoped.

**Environment: dev**

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | dev managed identity client ID |
| `AZURE_TENANT_ID` | dev tenant ID |
| `AZURE_SUBSCRIPTION_ID` | dev subscription ID |

**Environment: production**

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | prod managed identity client ID |
| `AZURE_TENANT_ID` | prod tenant ID |
| `AZURE_SUBSCRIPTION_ID` | prod subscription ID |

### 5. Create GitHub Environments

Settings → Environments

| Environment | Required reviewers | Deployment branch |
|-------------|-------------------|-------------------|
| `dev` | None | Any |
| `production` | Add yourself | `main` only |

### 6. Push to main

Workflow triggers automatically. Dev deploys first, prod deploys after approval.

---

## Folder Structure

```
.
├── .github/
│   └── workflows/
│       ├── infra.yml          # Terraform: provisions Azure infra
│       └── deploy.yml         # Build + deploy .NET 10 app via OIDC
├── infra/
│   ├── main.tf                # RG, ASP, Web App, OIDC identity, roles
│   ├── outputs.tf             # Prints values needed for GH secrets
│   ├── terraform.tfvars.example  # Template — safe to commit
│   └── terraform.tfvars       # Real values — gitignored, never commit
├── src/                       # .NET 10 Razor Pages app
├── bootstrap.sh               # One-time: creates TF state storage
└── README.md
```

---

## Security Properties

| Property | Value |
|----------|-------|
| Token lifetime | ~15 minutes per workflow run |
| Static secrets stored | None |
| Blast radius | Contributor on dev/prod subscription (scoped per environment) |
| OIDC subject pin | repo + environment (dev or production) |
| Audit trail | Azure Activity Log shows identity + workflow run |
| Rotation required | Never |
| Kudu SCM access | Not directly granted |

---

## Workflow: What Happens on Merge to Main

1. `build` job: restore → build → test → publish → upload artifact
2. `deploy-dev` job: OIDC login to dev sub → deploy to `my-dotnet-app-dev`
3. `deploy-prod` job: waits for approval → OIDC login to prod sub → deploy to `my-dotnet-app-prod`
4. `az logout` after each deploy
5. Tokens expire within 15 minutes regardless

---

## Tech Stack

- **Runtime:** .NET 10 (ASP.NET Core Razor Pages)
- **Hosting:** Azure App Service (Linux, B1)
- **IaC:** Terraform (azurerm ~> 4.0, remote state in Azure Storage)
- **CI/CD:** GitHub Actions
- **Auth:** OIDC federated identity (User-Assigned Managed Identity)
- **Version control:** GitHub (public repo, branch protection on main)
