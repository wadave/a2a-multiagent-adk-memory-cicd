# CI/CD Setup Guide - GitHub Actions with Google Cloud

This guide provides step-by-step instructions to set up automated CI/CD deployment using GitHub Actions and Workload Identity Federation (WIF) with Google Cloud.

## Overview

The CI/CD pipeline automatically deploys your application when you push to:
- `staging` branch → Deploys to staging environment (dw-genai-dev)
- `main` branch → Deploys to production environment (dw-genai-prod)

**Authentication Method**: Workload Identity Federation (WIF) - No service account keys needed!

For understanding how WIF authentication works, see [github-actions-wif-auth.md](github-actions-wif-auth.md).

## Prerequisites

- Google Cloud Project with billing enabled
- Project Owner or Security Admin role
- GitHub repository with admin access
- `gcloud` CLI installed and authenticated

## Part 1: Google Cloud Setup

### Step 1: Enable Required APIs

```bash
# Set your project
export PROJECT_ID="your-project-id"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# Enable APIs
gcloud services enable \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  aiplatform.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --project=$PROJECT_ID
```

### Step 2: Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-runner \
  --display-name="GitHub Actions Runner" \
  --description="Service account for GitHub Actions CI/CD" \
  --project=$PROJECT_ID

# Grant necessary roles
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
```

### Step 3: Create Workload Identity Pool

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --description="Workload Identity Pool for GitHub Actions" \
  --project=$PROJECT_ID

# Get the pool ID
export POOL_ID=$(gcloud iam workload-identity-pools describe github \
  --location="global" \
  --project=$PROJECT_ID \
  --format="value(name)")

echo "Pool ID: $POOL_ID"
```

### Step 4: Create Workload Identity Provider

```bash
# Set your GitHub repository
export GITHUB_OWNER="your-github-username"
export GITHUB_REPO="a2a-multiagent-adk-memory-cicd"

# Create provider
gcloud iam workload-identity-pools providers create-oidc github-actions \
  --location="global" \
  --workload-identity-pool="github" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor,attribute.aud=assertion.aud" \
  --attribute-condition="assertion.repository_owner=='${GITHUB_OWNER}'" \
  --project=$PROJECT_ID

# Get the provider resource name
export PROVIDER_NAME=$(gcloud iam workload-identity-pools providers describe github-actions \
  --location="global" \
  --workload-identity-pool="github" \
  --project=$PROJECT_ID \
  --format="value(name)")

echo "Provider Name: $PROVIDER_NAME"
```

### Step 5: Grant Service Account Access to Workload Identity

```bash
# Allow the GitHub Actions workflow to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding \
  "github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/${GITHUB_OWNER}/${GITHUB_REPO}" \
  --project=$PROJECT_ID
```

### Step 6: Save Configuration Values

Save these values - you'll need them for GitHub configuration:

```bash
echo "=== Save These Values ==="
echo "PROJECT_ID: $PROJECT_ID"
echo "PROJECT_NUMBER: $PROJECT_NUMBER"
echo "WORKLOAD_IDENTITY_PROVIDER: $PROVIDER_NAME"
echo "SERVICE_ACCOUNT: github-runner@${PROJECT_ID}.iam.gserviceaccount.com"
echo "=========================="
```

## Part 2: GitHub Repository Setup

### Step 7: Configure GitHub Environments

1. Go to your GitHub repository
2. Navigate to **Settings** → **Environments**
3. Create two environments:

#### Staging Environment
- Name: `staging`
- Environment protection rules: None (for faster iteration)
- Environment secrets/variables:
  - `PROJECT_ID`: `dw-genai-dev` (or your staging project)
  - `PROJECT_NUMBER`: Your staging project number
  - `WORKLOAD_IDENTITY_PROVIDER`: From Step 6
  - `SERVICE_ACCOUNT`: `github-runner@dw-genai-dev.iam.gserviceaccount.com`

#### Production Environment
- Name: `production`
- Environment protection rules:
  - ✓ Required reviewers (recommended)
  - ✓ Wait timer: 5 minutes (optional)
- Environment secrets/variables:
  - `PROJECT_ID`: `dw-genai-prod` (or your production project)
  - `PROJECT_NUMBER`: Your production project number
  - `WORKLOAD_IDENTITY_PROVIDER`: From Step 6 (production)
  - `SERVICE_ACCOUNT`: `github-runner@dw-genai-prod.iam.gserviceaccount.com`

### Step 8: Add Repository Secrets (Optional)

If you have secrets that should be available to all environments:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add repository secrets:
   - Any API keys
   - External service credentials
   - etc.

### Step 9: Verify Workflow File

The workflow file `.github/workflows/deploy.yml` should already be configured. Verify it contains:

```yaml
- name: Authenticate to Google Cloud
  id: auth
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: '${{ env.WORKLOAD_IDENTITY_PROVIDER }}'
    service_account: '${{ env.SERVICE_ACCOUNT }}'
```

## Part 3: Testing the Setup

### Step 10: Test Staging Deployment

```bash
# Make a small change
echo "# CI/CD Test" >> README.md

# Commit and push to staging
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin staging
```

### Step 11: Monitor the Deployment

```bash
# Watch the GitHub Actions run
gh run watch

# Or view in browser
gh run view --web
```

### Step 12: Verify Deployment

```bash
# Check deployed services
gcloud run services list --region us-central1 --project $PROJECT_ID

# Check deployed agents
gcloud ai reasoning-engines list --region us-central1 --project $PROJECT_ID
```

## Part 4: Production Deployment

### Step 13: Deploy to Production

```bash
# Merge staging to main
git checkout main
git merge staging
git push origin main
```

The production environment will:
- Require approval (if configured)
- Deploy to production project
- Apply production settings

## Troubleshooting

### Error: "Failed to generate Google Cloud access token"

**Cause**: Workload Identity Federation not configured correctly

**Solution**:
```bash
# Verify pool exists
gcloud iam workload-identity-pools describe github \
  --location="global" \
  --project=$PROJECT_ID

# Verify provider exists
gcloud iam workload-identity-pools providers describe github-actions \
  --location="global" \
  --workload-identity-pool="github" \
  --project=$PROJECT_ID

# Verify service account binding
gcloud iam service-accounts get-iam-policy \
  github-runner@${PROJECT_ID}.iam.gserviceaccount.com \
  --project=$PROJECT_ID
```

### Error: "Permission denied" during deployment

**Cause**: Service account lacks necessary permissions

**Solution**:
```bash
# Check current roles
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:github-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --format="table(bindings.role)"

# Add missing roles (see Step 2)
```

### Error: "Resource not found" for MCP servers

**Cause**: MCP servers need to be deployed first or URLs are incorrect

**Solution**:
- Deploy MCP servers manually first
- Or update workflow to skip checks for first deployment

### Pipeline runs but deployments are skipped

**Cause**: Change detection filters in workflow

**Solution**: Check which paths changed:
```bash
git diff HEAD~1 --name-only
```

The workflow only deploys components with changed files.

## Security Best Practices

1. **Use Separate Projects**: Different projects for staging and production
2. **Least Privilege**: Only grant necessary IAM roles
3. **Environment Protection**: Enable required reviewers for production
4. **Audit Logs**: Monitor Cloud Audit Logs for deployment activity
5. **Rotate Regularly**: While WIF doesn't use keys, rotate service accounts periodically
6. **Branch Protection**: Protect main branch, require PR reviews

## Cost Optimization

The CI/CD pipeline includes smart deployment:
- **Change Detection**: Only deploys changed components
- **Skip Logic**: Skips deployment if resources already exist
- **Terraform**: Manages infrastructure state efficiently

## Pipeline Behavior

### What Triggers Deployment?

- Push to `staging` → Staging deployment
- Push to `main` → Production deployment

### What Gets Deployed?

The pipeline detects changes in:
- `src/mcp_servers/**` → Deploys MCP servers
- `src/a2a_agents/**` → Deploys agents
- `src/frontend/**` → Deploys frontend
- `deployment/terraform/**` → Applies Terraform
- `.github/workflows/deploy.yml` → Deploys frontend

### Deployment Order

1. MCP Servers (Cloud Run)
2. Agents (Vertex AI Agent Engine)
3. Frontend (Cloud Run)
4. Infrastructure (Terraform)

## Advanced Configuration

### Custom Branch Deployments

Add to `.github/workflows/deploy.yml`:

```yaml
on:
  push:
    branches:
      - staging
      - main
      - feature/*  # Deploy feature branches
```

### Manual Workflow Trigger

Add to workflow:

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - staging
          - production
```

### Deployment Notifications

Add Slack/Discord notifications:

```yaml
- name: Notify on Success
  if: success()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Deployment succeeded for ${{ github.ref }}"
      }
```

## Next Steps

1. ✅ Complete WIF setup (Steps 1-6)
2. ✅ Configure GitHub environments (Steps 7-8)
3. ✅ Test staging deployment (Steps 10-12)
4. ✅ Review and approve for production (Step 13)
5. 📚 Read [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for adk-mb migration
6. 🧪 Review [TESTING_SUMMARY.md](TESTING_SUMMARY.md) for testing

## Support

For issues:
- Check [Troubleshooting](#troubleshooting) section above
- Review GitHub Actions logs: `gh run view --log`
- Check Cloud Console logs
- Review [github-actions-wif-auth.md](github-actions-wif-auth.md) for WIF concepts

## References

- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub Actions with Google Cloud](https://github.com/google-github-actions/auth)
- [CI/CD Best Practices](https://cloud.google.com/architecture/devops/devops-tech-continuous-delivery)
