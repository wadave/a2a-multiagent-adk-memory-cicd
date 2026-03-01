# CI/CD Setup Guide - GitHub Actions with Google Cloud

This guide sets up automated deployment using GitHub Actions and Workload Identity Federation (WIF). Once complete, pushing to `staging` or `main` automatically deploys the application — no service account keys required.

## Setup Checklist

Complete these steps **once** before the first deployment. The pipeline will not work until all required steps are done.

**Part 1 — Google Cloud (per environment)**
- [ ] Step 1: Enable required APIs
- [ ] Step 2: Create `github-runner` service account with required IAM roles
- [ ] Step 3: Create Workload Identity Pool
- [ ] Step 4: Create Workload Identity Provider
- [ ] Step 5: Grant service account access to Workload Identity
- [ ] Step 6: Note the configuration values

**Part 2 — GitHub (required before first push)**
- [ ] Step 7: Set environment variables in GitHub (`staging` and `production`) — ⚠️ pipeline fails without this
- [ ] Step 8: Add any optional repository secrets

**Part 3 — Deploy**
- [ ] Step 9: Push to `staging` and verify the pipeline passes

> **Repeat Part 1 for each GCP project** (staging and production use separate projects and separate service accounts).

---

## Prerequisites

- GCP project with billing enabled (one for staging, one for production)
- Project Owner role on each GCP project
- GitHub repository with admin access
- `gcloud` CLI installed and authenticated (`gcloud auth login`)
- `gh` CLI installed and authenticated (`gh auth login`)

For background on how WIF authentication works, see [github-actions-wif-auth.md](github-actions-wif-auth.md).

---

## Part 1: Google Cloud Setup

> Run these steps for **each** GCP project (staging, then production). Set `PROJECT_ID` accordingly each time.

### Step 1: Enable Required APIs

```bash
export PROJECT_ID="your-project-id"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

gcloud services enable \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  aiplatform.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  modelarmor.googleapis.com \
  --project=$PROJECT_ID
```

### Step 2: Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-runner \
  --display-name="GitHub Actions Runner" \
  --description="Service account for GitHub Actions CI/CD" \
  --project=$PROJECT_ID

# Grant roles needed to build and deploy application code
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/aiplatform.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Required for Terraform to enable/disable GCP APIs (google_project_service)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageAdmin"

# Required for Terraform to manage project-level IAM bindings (google_project_iam_member)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"
```

### Step 3: Create Workload Identity Pool

```bash
gcloud iam workload-identity-pools create github \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --description="Workload Identity Pool for GitHub Actions" \
  --project=$PROJECT_ID

export POOL_ID=$(gcloud iam workload-identity-pools describe github \
  --location="global" \
  --project=$PROJECT_ID \
  --format="value(name)")

echo "Pool ID: $POOL_ID"
```

### Step 4: Create Workload Identity Provider

```bash
export GITHUB_OWNER="your-github-username-or-org"
export GITHUB_REPO="a2a-multiagent-adk-memory-cicd"

gcloud iam workload-identity-pools providers create-oidc github-actions \
  --location="global" \
  --workload-identity-pool="github" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor,attribute.aud=assertion.aud" \
  --attribute-condition="assertion.repository_owner=='${GITHUB_OWNER}'" \
  --project=$PROJECT_ID

export PROVIDER_NAME=$(gcloud iam workload-identity-pools providers describe github-actions \
  --location="global" \
  --workload-identity-pool="github" \
  --project=$PROJECT_ID \
  --format="value(name)")

echo "Provider Name: $PROVIDER_NAME"
```

### Step 5: Grant Service Account Access to Workload Identity

```bash
gcloud iam service-accounts add-iam-policy-binding \
  "github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/${GITHUB_OWNER}/${GITHUB_REPO}" \
  --project=$PROJECT_ID
```

### Step 6: Note the Configuration Values

Print and save these — you need them in Step 7:

```bash
echo "PROJECT_ID:                   $PROJECT_ID"
echo "PROJECT_NUMBER:               $PROJECT_NUMBER"
echo "WORKLOAD_IDENTITY_PROVIDER:   $PROVIDER_NAME"
echo "SERVICE_ACCOUNT:              github-runner@${PROJECT_ID}.iam.gserviceaccount.com"
```

---

## Part 2: GitHub Repository Setup

### Step 7: Set Environment Variables in GitHub

> ⚠️ **This step is required before the first push.** The pipeline authenticates to Google Cloud using these variables. If they are missing or empty, the pipeline fails immediately with:
> `"must specify exactly one of workload_identity_provider or credentials_json"`

> **Variables vs Secrets**: The pipeline uses `${{ vars.* }}` — these are GitHub Actions **Variables** (non-sensitive config), not Secrets. Set them under **Environment variables**, not Environment secrets.

> 💡 `local.tfvars` is for local manual runs only. The pipeline ignores it. To change values the pipeline uses, update the variables here.

Use the `gh` CLI — run once after completing Step 6 for each project (using the same shell session so `$PROVIDER_NAME` etc. are still set):

```bash
# Set GITHUB_OWNER and GITHUB_REPO if not already set (from Step 4)
# export GITHUB_OWNER="your-github-username-or-org"
# export GITHUB_REPO="a2a-multiagent-adk-memory-cicd"
export GH_FULL_REPO="${GITHUB_OWNER}/${GITHUB_REPO}"

# --- Staging (run after Step 6 with staging PROJECT_ID) ---
gh variable set PROJECT_ID                 --env staging --body "$PROJECT_ID"      -R $GH_FULL_REPO
gh variable set PROJECT_NUMBER             --env staging --body "$PROJECT_NUMBER"   -R $GH_FULL_REPO
gh variable set WORKLOAD_IDENTITY_PROVIDER --env staging --body "$PROVIDER_NAME"   -R $GH_FULL_REPO
gh variable set SERVICE_ACCOUNT            --env staging \
  --body "github-runner@${PROJECT_ID}.iam.gserviceaccount.com" -R $GH_FULL_REPO

# Optional: only set if using Gemini Enterprise
# gh variable set GE_APP_STAGING             --env staging --body "your-ge-app-id"  -R $GH_FULL_REPO
# gh variable set OAUTH_CLIENT_ID_SECRET_NAME --env staging --body "client_secret"  -R $GH_FULL_REPO

# --- Production (re-run Step 1-6 with prod PROJECT_ID, then run these) ---
# gh variable set PROJECT_ID                 --env production --body "$PROJECT_ID"    -R $GH_FULL_REPO
# gh variable set PROJECT_NUMBER             --env production --body "$PROJECT_NUMBER" -R $GH_FULL_REPO
# gh variable set WORKLOAD_IDENTITY_PROVIDER --env production --body "$PROVIDER_NAME" -R $GH_FULL_REPO
# gh variable set SERVICE_ACCOUNT            --env production \
#   --body "github-runner@${PROJECT_ID}.iam.gserviceaccount.com" -R $GH_FULL_REPO
```

Verify after setting:

```bash
gh variable list --env staging    -R $GH_FULL_REPO
gh variable list --env production -R $GH_FULL_REPO
```

#### Required variables reference

| Variable | Required | Description |
|---|---|---|
| `PROJECT_ID` | ✅ | GCP project ID for this environment |
| `PROJECT_NUMBER` | ✅ | GCP project number for this environment |
| `WORKLOAD_IDENTITY_PROVIDER` | ✅ | Full WIF provider name from Step 6 |
| `SERVICE_ACCOUNT` | ✅ | `github-runner@PROJECT_ID.iam.gserviceaccount.com` |
| `GE_APP_STAGING` | optional | Gemini Enterprise App ID (skip if not using GE) |
| `OAUTH_CLIENT_ID_SECRET_NAME` | optional | Secret Manager secret name for GE OAuth credentials |

### Step 8: Add Repository Secrets (Optional)

For secrets shared across all environments (API keys, external credentials):

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add repository-level secrets as needed

---

## Part 3: Deploy

### Step 9: Test Staging Deployment

With Steps 1–8 complete, push any change to the `staging` branch:

```bash
git checkout staging
git commit --allow-empty -m "chore: trigger first CI/CD pipeline run"
git push origin staging
```

Monitor the run:

```bash
gh run watch -R $GH_FULL_REPO

# or open in browser
gh run view --web -R $GH_FULL_REPO
```

Verify deployed resources:

```bash
gcloud run services list --region us-central1 --project $PROJECT_ID
gcloud ai reasoning-engines list --region us-central1 --project $PROJECT_ID
```

### Step 10: Deploy to Production

```bash
git checkout main
git merge staging
git push origin main
```

The production environment will require approval if you configured required reviewers in Step 7.

---

## Pipeline Behavior

### What triggers deployment

| Push to branch | Deploys to |
|---|---|
| `staging` | Staging environment |
| `main` | Production environment |

### Change detection — what gets deployed

The pipeline only deploys components whose source files changed:

| Changed path | Action |
|---|---|
| `src/mcp_servers/**` | Rebuild and redeploy MCP servers (Cloud Run) |
| `src/a2a_agents/**` | Redeploy agents (Vertex AI Agent Engine) |
| `src/frontend/**` | Rebuild and redeploy frontend (Cloud Run) |
| `deployment/terraform/**` | Run `terraform apply` |
| `.github/workflows/deploy.yml` | Redeploy frontend |

### Deployment order within a run

1. **Terraform** — enables APIs, sets IAM, configures Model Armor
2. **MCP Servers** — Cloud Run services the agents call
3. **Agents** — Vertex AI Agent Engine (via `deploy_agents.py`)
4. **Frontend** — Cloud Run, configured with the agent engine ID from step 3

> Agents are deployed via `deploy_agents.py` (Python SDK), not Terraform, to avoid Terraform managing the full agent lifecycle. See [deployment strategy docs](docs/) for rationale.

---

## Troubleshooting

### "must specify exactly one of workload_identity_provider or credentials_json"

**Cause**: GitHub environment variables are missing or not yet set.

**Fix**: Complete Step 7. Verify variables exist:
```bash
gh variable list --env staging -R $GH_FULL_REPO
```
All four required variables (`PROJECT_ID`, `PROJECT_NUMBER`, `WORKLOAD_IDENTITY_PROVIDER`, `SERVICE_ACCOUNT`) must be present.

### "Failed to generate Google Cloud access token"

**Cause**: Workload Identity Federation not configured correctly.

**Fix**:
```bash
# Verify the pool exists
gcloud iam workload-identity-pools describe github \
  --location="global" --project=$PROJECT_ID

# Verify the provider exists
gcloud iam workload-identity-pools providers describe github-actions \
  --location="global" --workload-identity-pool="github" --project=$PROJECT_ID

# Verify the service account binding
gcloud iam service-accounts get-iam-policy \
  github-runner@${PROJECT_ID}.iam.gserviceaccount.com --project=$PROJECT_ID
```

### "PERMISSION_DENIED: Read access to project was denied" (Model Armor)

**Cause**: The `github-runner` service account is missing `roles/serviceusage.serviceUsageConsumer`. When using workload identity federation credentials, GCP requires this role to authorize the project as a quota project for newer APIs like Model Armor.

**Fix**: Grant the role (should be done in Step 2 — check if it's present):
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"
```

### "Permission denied" during Terraform IAM or API operations

**Cause**: Service account is missing `roles/resourcemanager.projectIamAdmin` or `roles/serviceusage.serviceUsageAdmin`.

**Fix**: Check current roles and add missing ones from Step 2:
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

### Pipeline runs but deployments are skipped

**Cause**: Change detection — the pipeline only deploys components with changed files.

**Fix**: Check what changed in your last commit:
```bash
git diff HEAD~1 --name-only
```

---

## Security Best Practices

1. **Separate projects**: Use different GCP projects for staging and production
2. **Least privilege**: Only grant the IAM roles listed in Step 2
3. **Environment protection**: Enable required reviewers for the `production` GitHub environment
4. **Branch protection**: Protect the `main` branch and require PR reviews
5. **Audit logs**: Monitor Cloud Audit Logs for deployment activity

---

## References

- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub Actions with Google Cloud](https://github.com/google-github-actions/auth)
- [CI/CD Best Practices](https://cloud.google.com/architecture/devops/devops-tech-continuous-delivery)
