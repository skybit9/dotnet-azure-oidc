<div align="center">

# 🚀 .NET 10 → Azure App Service
### via OIDC + Terraform + GitHub Actions

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![Terraform](https://img.shields.io/badge/Terraform-4.x-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-App_Service-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)

> **Zero static secrets. OIDC federated identity. IaC-managed infra. Multi-environment deployment.**

[![Dev](https://img.shields.io/badge/dev-my--dotnet--app--dev.azurewebsites.net-blue?style=flat-square&logo=microsoftazure)](https://my-dotnet-app-dev.azurewebsites.net)
[![Prod](https://img.shields.io/badge/prod-my--dotnet--app--prod.azurewebsites.net-success?style=flat-square&logo=microsoftazure)](https://my-dotnet-app-prod.azurewebsites.net)

</div>

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Actions                          │
│                                                             │
│   push to dev  ──►  Build + Test (CI gate)                  │
│   merge to main ──► Build + Test + Deploy                   │
└──────────────────────────┬──────────────────────────────────┘
                           │ mint OIDC JWT
                           │ repo:skybit9/dotnet-azure-oidc
                           │ :environment:dev|prod
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   GitHub OIDC Provider                      │
└──────────────────────────┬──────────────────────────────────┘
                           │ token exchange
                           ▼
┌─────────────────────────────────────────────────────────────┐
│      Azure AD (validates subject claim against              │
│      federated credential)                                  │
└──────────────────────────┬──────────────────────────────────┘
                           │ short-lived access token (~15 min)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│         User-Assigned Managed Identity                      │
│         Contributor role (subscription scope)               │
└────────────────┬─────────────────────┬──────────────────────┘
                 │                     │
                 ▼                     ▼
     ┌───────────────────┐   ┌───────────────────┐
     │  Azure Dev Sub    │   │  Azure Prod Sub    │
     │  my-dotnet-app    │   │  my-dotnet-app     │
     │  -dev             │   │  -prod             │
     │  (.NET 10, B1)    │   │  (.NET 10, B1)     │
     └───────────────────┘   └───────────────────┘
```

---

## 🌿 Branch Strategy

```
┌─────────────────────────────────────────────────────────────┐
│  dev branch                                                 │
│  push  ──►  🔨 Build + Test (no deploy)                     │
│  PR to main ──► 🔨 Build + Test must pass ──► merge allowed │
└──────────────────────────┬──────────────────────────────────┘
                           │ merge
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  main branch                                                │
│  🔨 Build + Test                                            │
│       ├──► 🟦 Deploy to DEV   (auto, no approval)           │
│       └──► 🟩 Deploy to PROD  (requires approval gate)      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🌍 Environments

| | Dev | Prod |
|--|-----|------|
| **Azure Subscription** | dev | prod |
| **Web App** | my-dotnet-app-dev | my-dotnet-app-prod |
| **GitHub Environment** | dev | prod |
| **Approval required** | ❌ No | ✅ Yes |
| **Deployment branch** | Any | `main` only |
| **OIDC Subject** | `environment:dev` | `environment:prod` |

---

## ⚡ Quick Start (First-Time Setup)

### 1️⃣ Bootstrap Terraform State Storage

```bash
chmod +x bootstrap.sh

# Dev subscription:
az account set --subscription "dev"
./bootstrap.sh

# Prod subscription:
az account set --subscription "prod"
./bootstrap.sh
```

### 2️⃣ Configure Variables

```bash
# Dev:
cp infra/terraform.tfvars.example infra/terraform.tfvars

# Prod:
cp infra/terraform.tfvars.example infra/terraform.tfvars.prod
# Edit: resource_group_name, webapp_name, github_environment = "prod"
```

> ⚠️ Both files are gitignored. Never commit them.

### 3️⃣ Provision Infrastructure

```bash
cd infra

# Dev:
az account set --subscription "dev"
terraform init && terraform apply

# Prod:
az account set --subscription "prod"
terraform init -backend-config="storage_account_name=PROD_SA_NAME" -reconfigure
terraform apply -var-file="terraform.tfvars.prod"
```

### 4️⃣ Set GitHub Secrets (per environment)

**Environment: `dev`**

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | `managed_identity_client_id` from `terraform output` |
| `AZURE_TENANT_ID` | `tenant_id` from `terraform output` |
| `AZURE_SUBSCRIPTION_ID` | dev subscription ID |

**Environment: `prod`**

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | prod managed identity client ID |
| `AZURE_TENANT_ID` | prod tenant ID |
| `AZURE_SUBSCRIPTION_ID` | prod subscription ID |

### 5️⃣ Create GitHub Environments

| Environment | Required reviewers | Deployment branch |
|-------------|-------------------|-------------------|
| `dev` | None | Any |
| `prod` | Add yourself | `main` only |

### 6️⃣ Push and Deploy

```bash
git push origin dev    # triggers Build + Test
# open PR → merge to main → triggers full deploy
```

---

## 📁 Folder Structure

```
dotnet-azure-oidc/
├── .github/
│   └── workflows/
│       ├── infra.yml               # Terraform: provisions Azure infra
│       └── deploy.yml              # Build + deploy .NET 10 via OIDC
├── infra/
│   ├── main.tf                     # RG, ASP, Web App, OIDC identity, roles
│   ├── outputs.tf                  # Prints values for GitHub secrets
│   ├── terraform.tfvars.example    # Template — safe to commit
│   └── terraform.tfvars            # Real values — gitignored ⚠️
├── src/                            # .NET 10 Razor Pages app
│   └── MyApp.csproj
├── bootstrap.sh                    # One-time TF state storage setup
├── .gitignore
└── README.md
```

---

## 🔒 Security Properties

| Property | Value |
|----------|-------|
| 🕐 Token lifetime | ~15 minutes per workflow run |
| 🔑 Static secrets stored | **None** |
| 💥 Blast radius | Contributor scoped per subscription |
| 📌 OIDC subject pin | `repo + environment` (dev or prod) |
| 📋 Audit trail | Azure Activity Log: identity + workflow run |
| 🔄 Rotation required | **Never** |
| 🚫 Kudu SCM access | Not directly granted |

---

## 🔄 What Happens on Merge to Main

```
1. 🔨  build job       → restore → build → test → publish → upload artifact
2. 🟦  deploy-dev job  → OIDC login (dev) → deploy to my-dotnet-app-dev → logout
3. ⏸️  approval gate   → reviewer approves prod deployment
4. 🟩  deploy-prod job → OIDC login (prod) → deploy to my-dotnet-app-prod → logout
5. ⏱️  tokens expire   → within 15 minutes regardless
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Runtime** | .NET 10 (ASP.NET Core Razor Pages) |
| **Hosting** | Azure App Service (Linux, B1) |
| **IaC** | Terraform (azurerm ~> 4.0) |
| **State** | Azure Storage Account (remote backend) |
| **CI/CD** | GitHub Actions |
| **Auth** | OIDC + User-Assigned Managed Identity |
| **Source control** | GitHub (public, branch protection on `main`) |

---

<div align="center">

Built by **skybit9** · [View on GitHub](https://github.com/skybit9/dotnet-azure-oidc)

</div>
