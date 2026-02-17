# CI/CD Quick Reference Guide

Quick reference for common CI/CD operations and troubleshooting.

## Deployment Triggers

### What Gets Deployed When You Push Changes?

| Change Location | What Deploys | Why |
|----------------|--------------|-----|
| `src/mcp_servers/cocktail_mcp_server/**` | Cocktail MCP → All Agents → Frontend | Dependency cascade |
| `src/mcp_servers/weather_mcp_server/**` | Weather MCP → All Agents → Frontend | Dependency cascade |
| `src/a2a_agents/**` | All Agents → Frontend | Frontend needs new agent ID |
| `src/frontend/**` | Frontend only | No downstream dependencies |
| `deployment/terraform/**` | Terraform state sync | Infrastructure updates |

## Environment Variables

### MCP Servers
```bash
# No environment variables needed
# Deployed with --allow-unauthenticated flag
```

### Agents (in deploy_agents.py)
```bash
PROJECT_ID=your-project-id
PROJECT_NUMBER=your-project-number
GOOGLE_CLOUD_REGION=us-central1
CT_MCP_SERVER_URL=https://cocktail-mcp-server-url/mcp/sse
WEA_MCP_SERVER_URL=https://weather-mcp-server-url/mcp/sse
GOOGLE_GENAI_MODEL=gemini-2.5-flash
```

### Frontend (in Cloud Run)
```bash
PROJECT_ID=your-project-id
PROJECT_NUMBER=your-project-number
GOOGLE_CLOUD_LOCATION=us-central1
AGENT_ENGINE_ID=projects/.../reasoningEngines/...
```

## Common Commands

### Check Deployment Status
```bash
# View GitHub Actions run
gh run list --workflow=deploy.yml --limit 5

# View logs for latest run
gh run view --log

# Watch live deployment
gh run watch
```

### View Deployed Resources
```bash
# MCP Servers
gcloud run services list --region=us-central1 | grep mcp-server

# Agents
gcloud ai reasoning-engines list --region=us-central1

# Frontend
gcloud run services describe a2a-frontend-adk-mb --region=us-central1
```

### Get Resource URLs
```bash
# Cocktail MCP Server URL
gcloud run services describe cocktail-remote-mcp-server-adk-mb \
  --region=us-central1 \
  --format='value(status.url)'

# Weather MCP Server URL
gcloud run services describe weather-remote-mcp-server-adk-mb \
  --region=us-central1 \
  --format='value(status.url)'

# Frontend URL
gcloud run services describe a2a-frontend-adk-mb \
  --region=us-central1 \
  --format='value(status.url)'
```

### Get Agent Engine ID
```bash
gcloud ai reasoning-engines list \
  --region=us-central1 \
  --filter='displayName:"Hosting Agent adk-mb - ADK"' \
  --format='value(name)'
```

### View Terraform State
```bash
cd deployment/terraform

# View current state
terraform show

# View outputs
terraform output

# View specific output
terraform output cocktail_mcp_server_url
```

## Troubleshooting

### Issue: Agents Not Using New MCP Server URLs

**Check**:
```bash
# 1. Verify MCP server deployed
gcloud run services describe cocktail-remote-mcp-server-adk-mb --region=us-central1

# 2. Check GitHub Actions logs for "Get MCP Server URLs" step
gh run view --log | grep "Get MCP Server URLs" -A 20

# 3. Check if agents were redeployed
gh run view --log | grep "DEPLOY_AGENTS" -A 5
```

**Fix**:
- Check deployment flags step in workflow
- Ensure dependency cascade logic is working
- Manually redeploy agents if needed

### Issue: Frontend Shows Old Agent Engine ID

**Check**:
```bash
# 1. Get current agent engine ID
gcloud ai reasoning-engines list --region=us-central1

# 2. Check frontend environment variables
gcloud run services describe a2a-frontend-adk-mb \
  --region=us-central1 \
  --format='yaml(spec.template.spec.containers[0].env)'

# 3. Check GitHub Actions logs
gh run view --log | grep "Get Agent Engine ID" -A 10
```

**Fix**:
```bash
# Redeploy frontend with correct agent ID
AGENT_ID=$(gcloud ai reasoning-engines list \
  --region=us-central1 \
  --filter='displayName:"Hosting Agent adk-mb - ADK"' \
  --format='value(name)')

gcloud run services update a2a-frontend-adk-mb \
  --region=us-central1 \
  --update-env-vars="AGENT_ENGINE_ID=$AGENT_ID"
```

### Issue: Terraform Import Fails

**Error**: `Resource already exists in state`

**Fix**:
```bash
cd deployment/terraform

# Remove from state
terraform state rm google_cloud_run_v2_service.cocktail_mcp_server

# Re-import
terraform import \
  google_cloud_run_v2_service.cocktail_mcp_server \
  "projects/PROJECT_ID/locations/us-central1/services/cocktail-remote-mcp-server-adk-mb"
```

### Issue: Deployment Stuck or Failed

**Check**:
```bash
# View detailed logs
gh run view --log-failed

# Check Cloud Build logs
gcloud builds list --limit=5

# Check Cloud Run revisions
gcloud run revisions list --service=SERVICE_NAME --region=us-central1
```

**Fix**:
```bash
# Cancel the workflow run
gh run cancel RUN_ID

# Fix the issue in code
# Push fix to trigger new deployment

# Or manually deploy
gcloud run deploy SERVICE_NAME \
  --image gcr.io/PROJECT_ID/IMAGE_NAME \
  --region=us-central1
```

## Deployment Scenarios

### Scenario 1: Update MCP Server

```bash
# 1. Edit code
vim src/mcp_servers/cocktail_mcp_server/main.py

# 2. Commit and push
git add src/mcp_servers/cocktail_mcp_server/
git commit -m "feat: update cocktail MCP server"
git push origin staging

# 3. Monitor deployment
gh run watch

# 4. Verify cascade
# - MCP server deployed ✓
# - Agents redeployed ✓
# - Frontend redeployed ✓
```

### Scenario 2: Update Agent Code

```bash
# 1. Edit code
vim src/a2a_agents/cocktail_agent/agent_executor.py

# 2. Commit and push
git add src/a2a_agents/
git commit -m "feat: update cocktail agent logic"
git push origin staging

# 3. Monitor deployment
gh run watch

# 4. Verify cascade
# - Agents redeployed ✓
# - Frontend redeployed ✓
```

### Scenario 3: Update Frontend

```bash
# 1. Edit code
vim src/frontend/main.py

# 2. Commit and push
git add src/frontend/
git commit -m "feat: update frontend UI"
git push origin staging

# 3. Monitor deployment
gh run watch

# 4. Verify deployment
# - Frontend redeployed ✓
```

## Manual Deployment

If CI/CD is down or you need to deploy manually:

### Deploy MCP Servers
```bash
# Cocktail MCP
cd src/mcp_servers/cocktail_mcp_server
gcloud builds submit --tag gcr.io/PROJECT_ID/cocktail-remote-mcp-server-adk-mb
gcloud run deploy cocktail-remote-mcp-server-adk-mb \
  --image gcr.io/PROJECT_ID/cocktail-remote-mcp-server-adk-mb \
  --region us-central1 \
  --allow-unauthenticated

# Weather MCP
cd ../weather_mcp_server
gcloud builds submit --tag gcr.io/PROJECT_ID/weather-remote-mcp-server-adk-mb
gcloud run deploy weather-remote-mcp-server-adk-mb \
  --image gcr.io/PROJECT_ID/weather-remote-mcp-server-adk-mb \
  --region us-central1 \
  --allow-unauthenticated
```

### Deploy Agents
```bash
# Set environment variables
export PROJECT_ID="your-project-id"
export PROJECT_NUMBER="your-project-number"
export GOOGLE_CLOUD_REGION="us-central1"
export CT_MCP_SERVER_URL="https://cocktail-mcp-url/mcp/sse"
export WEA_MCP_SERVER_URL="https://weather-mcp-url/mcp/sse"

# Deploy
cd deployment
python deploy_agents.py
```

### Deploy Frontend
```bash
# Get agent engine ID
AGENT_ID=$(gcloud ai reasoning-engines list \
  --region=us-central1 \
  --filter='displayName:"Hosting Agent adk-mb - ADK"' \
  --format='value(name)')

# Deploy frontend
cd src/frontend
gcloud builds submit --tag gcr.io/PROJECT_ID/a2a-frontend-adk-mb
gcloud run deploy a2a-frontend-adk-mb \
  --image gcr.io/PROJECT_ID/a2a-frontend-adk-mb \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="PROJECT_ID=PROJECT_ID,PROJECT_NUMBER=PROJECT_NUMBER,AGENT_ENGINE_ID=$AGENT_ID,GOOGLE_CLOUD_LOCATION=us-central1"
```

## Monitoring

### View Logs

```bash
# Cloud Run logs
gcloud run services logs read SERVICE_NAME --region=us-central1 --limit=50

# Cloud Build logs
gcloud builds log BUILD_ID

# Terraform logs
cd deployment/terraform
terraform show
```

### Health Checks

```bash
# Check MCP server health
curl https://cocktail-mcp-server-url/health

# Check frontend health
curl https://frontend-url/

# Test agent query (requires auth token)
curl -X POST https://AGENT_URL/query \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'
```

## Rollback

### Rollback Cloud Run Service
```bash
# List revisions
gcloud run revisions list --service=SERVICE_NAME --region=us-central1

# Rollback to previous revision
gcloud run services update-traffic SERVICE_NAME \
  --to-revisions=PREVIOUS_REVISION=100 \
  --region=us-central1
```

### Rollback Terraform
```bash
cd deployment/terraform

# View state history
gsutil ls -l gs://PROJECT_ID-terraform-state/a2a-multiagent-adk-memory-cicd/

# Restore previous state
gsutil cp gs://BUCKET/PATH/terraform.tfstate.TIMESTAMP terraform.tfstate

# Apply previous state
terraform apply
```

### Rollback Git
```bash
# Revert last commit
git revert HEAD
git push origin staging

# Revert to specific commit
git revert COMMIT_HASH
git push origin staging
```

## Best Practices

1. **Always test in staging first**
   ```bash
   git push origin staging
   # Wait for deployment and test
   git push origin main  # Promote to production
   ```

2. **Monitor deployments**
   ```bash
   gh run watch
   ```

3. **Verify cascade updates**
   - Check deployment summary in logs
   - Verify resource URLs are updated

4. **Use Terraform outputs**
   ```bash
   cd deployment/terraform
   terraform output
   ```

5. **Keep documentation updated**
   - Update this file when adding new services
   - Document environment variables

## Links

- [GitHub Repository](https://github.com/your-org/a2a-multiagent-adk-memory-cicd)
- [GitHub Actions](https://github.com/your-org/a2a-multiagent-adk-memory-cicd/actions)
- [Cloud Console](https://console.cloud.google.com)
- [Cloud Run Services](https://console.cloud.google.com/run)
- [Agent Engine](https://console.cloud.google.com/vertex-ai/reasoning-engines)

## Support

- Check deployment logs first
- Review [CICD_DEPENDENCY_MANAGEMENT.md](CICD_DEPENDENCY_MANAGEMENT.md)
- Review [CICD_ROBUSTNESS_IMPROVEMENTS.md](CICD_ROBUSTNESS_IMPROVEMENTS.md)
- File an issue with logs attached
- Contact DevOps team
