# CI/CD Dependency Management

This document explains how the CI/CD pipeline ensures robust dependency management between MCP servers, agents, and frontend components.

## Overview

The application has the following dependency chain:

```
MCP Servers (Cocktail, Weather)
    ↓
A2A Agents (Cocktail Agent, Weather Agent, Hosting Agent)
    ↓
Frontend (Gradio Web Interface)
```

When upstream components change, downstream components must be updated to use the correct resource IDs and URLs.

## Key Improvements

### 1. **Automatic Dependency Cascade**

The CI/CD pipeline now automatically triggers downstream deployments when upstream dependencies change:

- **MCP Server Update** → Triggers agent redeployment with new MCP server URLs
- **Agent Update** → Triggers frontend redeployment with new agent engine ID
- **Any Upstream Change** → Cascades updates through all dependent components

### 2. **Dynamic Resource URL Resolution**

Instead of hardcoding resource URLs, the pipeline dynamically fetches them after deployment:

```yaml
# Get MCP Server URLs dynamically after deployment
- name: Get MCP Server URLs
  id: mcp_urls
  run: |
    CT_URL=$(gcloud run services describe cocktail-remote-mcp-server-adk-mb ...)
    echo "CT_MCP_SERVER_URL=${CT_URL}/mcp/sse" >> $GITHUB_OUTPUT
```

### 3. **Intelligent Deployment Flags**

The pipeline uses smart flags to determine what needs to be deployed:

```yaml
- name: Set deployment flags
  run: |
    # Deploy agents if agent code changed OR any MCP server changed
    if [ "${{ steps.changes.outputs.agents }}" == "true" ] || \
       [ "${{ steps.changes.outputs.cocktail_mcp }}" == "true" ] || \
       [ "${{ steps.changes.outputs.weather_mcp }}" == "true" ]; then
      echo "DEPLOY_AGENTS=true" >> $GITHUB_OUTPUT
    fi
```

### 4. **Terraform State Management**

Terraform now manages the infrastructure state and includes:
- IAM policy bindings for service accounts
- Environment variable injection for all services
- Output exports for downstream consumption
- Proper resource dependency tracking

## Deployment Flow

### When MCP Server Code Changes:

1. **Build & Deploy MCP Server** (.github/workflows/deploy.yml:121-147)
   - Builds new container image
   - Deploys to Cloud Run
   - Updates service with latest code

2. **Get Updated MCP Server URLs** (.github/workflows/deploy.yml:149-171)
   - Fetches actual URLs from deployed services
   - Exports URLs for downstream use

3. **Redeploy Agents** (.github/workflows/deploy.yml:173-203)
   - Detects MCP server change via deployment flags
   - Redeploys agents with updated MCP server URLs
   - Agents now point to the new MCP server instances

4. **Redeploy Frontend** (.github/workflows/deploy.yml:205-230)
   - Gets latest agent engine ID
   - Redeploys frontend with correct agent ID
   - Frontend now uses updated agents

5. **Update Terraform State** (.github/workflows/deploy.yml:232-280)
   - Imports current resource state
   - Applies infrastructure configuration
   - Updates IAM bindings

### When Agent Code Changes:

1. **Redeploy Agents**
   - Uses existing MCP server URLs
   - Updates agent logic
   - Exports new agent engine ID

2. **Redeploy Frontend**
   - Detects agent change
   - Updates with new agent engine ID

3. **Update Terraform State**
   - Syncs infrastructure state

### When Frontend Code Changes:

1. **Redeploy Frontend**
   - Uses existing agent engine ID
   - Updates frontend code only

2. **Update Terraform State**
   - Syncs infrastructure state

## File Changes

### New Files Created:

1. **deployment/terraform/outputs.tf**
   - Exports MCP server URLs
   - Exports agent engine ID
   - Exports Cloud Run service names
   - Provides outputs for downstream consumption

2. **deployment/terraform/iam.tf**
   - IAM bindings for public access to services
   - Compute service account permissions
   - Invoker roles for Cloud Run services

### Modified Files:

1. **deployment/terraform/cloudrun.tf**
   - Added environment variables to frontend (PROJECT_ID, PROJECT_NUMBER, GOOGLE_CLOUD_LOCATION)
   - Uses data source for project number

2. **.github/workflows/deploy.yml**
   - Removed checks that prevented redeployment of existing services
   - Added dependency cascade logic
   - Added dynamic URL resolution
   - Added deployment summary output
   - Improved error handling

## Terraform Infrastructure

### Resources Managed:

- `google_cloud_run_v2_service.cocktail_mcp_server`: Cocktail MCP Server
- `google_cloud_run_v2_service.weather_mcp_server`: Weather MCP Server
- `google_cloud_run_v2_service.a2a_frontend`: Frontend service
- IAM bindings for all services

### Key Features:

1. **Lifecycle Management**
   ```hcl
   lifecycle {
     ignore_changes = [
       template[0].containers[0].image,
     ]
   }
   ```
   - Prevents Terraform from overwriting manually deployed images
   - Allows CI/CD to manage container images independently

2. **Environment Variable Injection**
   - Frontend receives all necessary environment variables
   - Variables are injected via Terraform and CI/CD

3. **IAM Policy Automation**
   - Automatic public access configuration
   - Compute service account permissions for inter-service communication

## Verification

After deployment, you can verify the dependency chain:

```bash
# 1. Check MCP Server URLs
gcloud run services describe cocktail-remote-mcp-server-adk-mb \
  --region=us-central1 \
  --format='value(status.url)'

# 2. Check Agent Engine ID
gcloud ai reasoning-engines list \
  --region=us-central1 \
  --filter='displayName:"Hosting Agent adk-mb - ADK"'

# 3. Check Frontend Environment Variables
gcloud run services describe a2a-frontend-adk-mb \
  --region=us-central1 \
  --format='value(spec.template.spec.containers[0].env)'

# 4. View Terraform Outputs
cd deployment/terraform
terraform output
```

## Best Practices

1. **Always Use Dynamic URLs**: Never hardcode resource URLs in the pipeline
2. **Check Deployment Flags**: Use the intelligent flags to determine what needs deployment
3. **Monitor Cascading Updates**: Watch logs to ensure downstream components get updated
4. **Verify State Sync**: Ensure Terraform state stays in sync with actual infrastructure
5. **Test Dependency Chain**: After major changes, manually verify the entire dependency chain

## Troubleshooting

### Issue: Agents Not Updated After MCP Server Change

**Solution**: Check the deployment flags step. Ensure `DEPLOY_AGENTS=true` when MCP servers change.

```yaml
# .github/workflows/deploy.yml line ~113
- name: Set deployment flags
  id: deploy_flags
```

### Issue: Frontend Has Stale Agent Engine ID

**Solution**: Check the agent ID resolution step:

```yaml
# .github/workflows/deploy.yml line ~205
- name: Get Agent Engine ID
  id: agent_id
```

### Issue: Terraform Import Fails

**Solution**: Resources might not exist yet. The import commands use `|| true` to continue on failure, which is expected for new deployments.

### Issue: Missing MCP Server URLs

**Solution**: Ensure MCP servers are deployed before agents. Check the step ordering in the workflow:
1. Deploy MCP Servers (step 3)
2. Get MCP URLs (step 4)
3. Deploy Agents (step 5)

## Deployment Scenarios

### Scenario 1: Fresh Deployment (No Existing Resources)

1. MCP servers are built and deployed to Cloud Run
2. MCP URLs are fetched and exported
3. Agents are deployed with MCP URLs
4. Agent engine ID is exported
5. Frontend is deployed with agent engine ID
6. Terraform imports and syncs state

### Scenario 2: MCP Server Code Update

1. Changed MCP server is redeployed
2. New MCP URLs are fetched
3. **All agents are redeployed** with updated MCP URLs
4. New agent engine IDs are fetched
5. **Frontend is redeployed** with updated agent engine ID
6. Terraform syncs state

### Scenario 3: Agent Code Update

1. Existing MCP URLs are used
2. Agents are redeployed with code changes
3. New agent engine ID is exported
4. **Frontend is redeployed** with new agent engine ID
5. Terraform syncs state

### Scenario 4: Frontend Code Update

1. Existing agent engine ID is fetched
2. Frontend is redeployed with code changes
3. Terraform syncs state

## Architecture Decisions

### Why Not Use Terraform to Deploy Agents?

Agents are deployed via Python script (`deployment/deploy_agents.py`) instead of Terraform because:
- Vertex AI Agent Engine doesn't have stable Terraform provider support
- Python SDK provides better error handling and retry logic
- Agent deployment requires complex orchestration not suitable for Terraform

### Why Store State in GCS?

Terraform state is stored in Google Cloud Storage (GCS) to:
- Enable collaboration across CI/CD runs
- Maintain infrastructure state across deployments
- Support rollback and recovery scenarios
- Separate state per environment (staging/prod)

### Why Use Lifecycle ignore_changes for Images?

The `ignore_changes` lifecycle rule for container images allows:
- CI/CD to manage image updates independently
- Terraform to focus on infrastructure configuration
- Faster deployments without Terraform plan/apply for every image change

## Security Considerations

1. **Service Account Permissions**
   - Compute service account has minimal permissions
   - Only granted Cloud Run invoker role
   - No overly broad IAM bindings

2. **Workload Identity Federation**
   - No service account keys stored in GitHub
   - Token-based authentication for GitHub Actions
   - Scoped to specific repositories and branches

3. **Public Access**
   - MCP servers and frontend allow unauthenticated access by design
   - For production, consider adding authentication layers
   - Use Cloud Armor for DDoS protection

## Future Enhancements

1. **Health Checks**: Add health check endpoints to all services
2. **Canary Deployments**: Implement gradual rollout for agents and frontend
3. **Rollback Mechanism**: Add ability to rollback to previous versions
4. **Resource Tagging**: Tag all resources with deployment metadata
5. **Cost Tracking**: Add budget alerts and cost tracking per environment
6. **Monitoring**: Integrate Cloud Monitoring and Alerting
7. **Testing**: Add integration tests in CI/CD pipeline before deployment

## Related Documentation

- [CICD_SETUP_GUIDE.md](CICD_SETUP_GUIDE.md): Initial CI/CD setup
- [README.md](README.md): Project overview and manual deployment
- [TESTING_SUMMARY.md](TESTING_SUMMARY.md): Testing strategy
