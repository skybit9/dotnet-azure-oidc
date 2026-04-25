# .NET 9 → Azure App Service via OIDC + Terraform

Zero static secrets. OIDC federated identity. IaC-managed infra.

---

## Architecture

```
GitHub Actions (deploy job)
  │
  │  mint OIDC JWT (repo:ORG/REPO:environment:production)
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
  │  Website Contributor role (scoped to web app only)
  ▼
Azure Linux Web App (.NET 9, B1)
```

---

## First-Time Setup (run once)

### 1. Bootstrap Terraform state storage

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

Copy the printed `storage_account_name` into `infra/main.tf` backend block.

### 2. Create Service Principal for Terraform itself

Terraform needs its own auth to create Azure resources:

```bash
az ad sp create-for-rbac \
  --name "terraform-dotnet-app-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```

Save the output JSON. You'll need `clientId`, `clientSecret`, `tenantId`, `subscriptionId`.

### 3. Configure terraform.tfvars

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit terraform.tfvars with your values
```

Add `terraform.tfvars` to `.gitignore`.

### 4. Apply Terraform

```bash
cd infra
terraform init
terraform plan
terraform apply
```

Note the outputs:
- `managed_identity_client_id` → AZURE_CLIENT_ID
- `tenant_id`                  → AZURE_TENANT_ID
- your subscription ID         → AZURE_SUBSCRIPTION_ID

### 5. Set GitHub Secrets

In your repo: Settings → Secrets and variables → Actions

| Secret name              | Value                              |
|--------------------------|------------------------------------|
| `AZURE_CLIENT_ID`        | `managed_identity_client_id` output |
| `AZURE_TENANT_ID`        | `tenant_id` output                 |
| `AZURE_SUBSCRIPTION_ID`  | Your Azure subscription ID         |

> NOTE: These are NOT credentials. Client ID + Tenant ID + Sub ID are
> identifiers. The actual auth is the OIDC token GitHub mints at runtime.
> There is no password or secret to rotate.

### 6. Create GitHub Environment

In your repo: Settings → Environments → New environment → name: `production`

Recommended settings:
- Required reviewers: add yourself or team lead
- Deployment branches: restrict to `main` only

### 7. Push to main

The `deploy.yml` workflow triggers automatically on push to `main`.

---

## Folder Structure

```
.
├── .github/
│   └── workflows/
│       ├── infra.yml      # Terraform: provisions Azure infra
│       └── deploy.yml     # Build + deploy .NET 9 app via OIDC
├── infra/
│   ├── main.tf            # RG, ASP, Web App, OIDC identity, role
│   ├── outputs.tf         # Prints values needed for GH secrets
│   └── terraform.tfvars.example
├── src/                   # Your .NET 9 project lives here
├── bootstrap.sh           # One-time: creates TF state storage
└── README.md
```

---

## Security Properties

| Property              | Value                                      |
|-----------------------|--------------------------------------------|
| Token lifetime        | ~15 minutes per workflow run               |
| Static secrets stored | None (AZURE_CLIENT_ID is not a secret)     |
| Blast radius          | Website Contributor on 1 web app only      |
| OIDC subject pin      | repo + environment (not just branch)       |
| Audit trail           | Azure Activity Log shows identity + run    |
| Rotation required     | Never                                      |
| Kudu SCM access       | NOT granted (Website Contributor only)     |

---

## Workflow: What Happens on Push to Main

1. `build` job runs: restore → build → test → publish → upload artifact
2. If tests pass, `deploy` job queues (waits for environment approval if configured)
3. GitHub mints OIDC JWT with subject `repo:ORG/REPO:environment:production`
4. `azure/login@v2` exchanges JWT for short-lived Azure AD token
5. `azure/webapps-deploy@v3` pushes artifact to App Service
6. `az logout` clears token immediately
7. Token expires anyway within 15 minutes
