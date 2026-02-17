# Migration Guide: "adk-memory" to "adk-mb"

## Overview

This guide explains how to migrate from the old "adk-memory" naming convention to the new "adk-mb" naming convention.

## Current State

### Old Naming (Deployed)
- `cocktail-remote-mcp-server-adk-memory` (Cloud Run)
- `weather-remote-mcp-server-adk-memory` (Cloud Run)
- `a2a-frontend-adk-memory` (Cloud Run)
- `Cocktail Agent adk-memory - ADK` (Agent Engine)
- `Weather Agent adk-memory - ADK` (Agent Engine)
- `Hosting Agent adk-memory - ADK` (Agent Engine)

### New Naming (Configured)
- `cocktail-remote-mcp-server-adk-mb` (Terraform, CI/CD)
- `weather-remote-mcp-server-adk-mb` (Terraform, CI/CD)
- `a2a-frontend-adk-mb` (Terraform, CI/CD)
- `Cocktail Agent adk-mb - ADK` (Agent Cards)
- `Weather Agent adk-mb - ADK` (Agent Cards)
- `Hosting Agent adk-mb - ADK` (Agent Cards)

## Migration Options

### Option 1: Blue-Green Deployment (Recommended)

Deploy new services alongside old ones, then switch over.

**Advantages**:
- Zero downtime
- Easy rollback
- Test new services before switching

**Steps**:

1. **Deploy new services** (CI/CD will create them):
   ```bash
   git add .
   git commit -m "refactor: update naming to adk-mb"
   git push origin staging
   ```

2. **Wait for CI/CD to complete** - New services will be created:
   - `cocktail-remote-mcp-server-adk-mb`
   - `weather-remote-mcp-server-adk-mb`
   - `a2a-frontend-adk-mb`
   - New agent engines with "adk-mb" names

3. **Test new services**:
   ```bash
   # Test new MCP servers
   curl https://cocktail-remote-mcp-server-adk-mb-496235138247.us-central1.run.app/health

   # Test new frontend
   curl https://a2a-frontend-adk-mb-496235138247.us-central1.run.app

   # Run integration tests
   python tests/integration/test_hosting_agent_remote.py
   python tests/integration/test_frontend_deployed.py
   ```

4. **Update external references** (if any):
   - Update any bookmarks
   - Update documentation
   - Notify users of new URLs

5. **Delete old services**:
   ```bash
   # Delete old Cloud Run services
   gcloud run services delete cocktail-remote-mcp-server-adk-memory \
     --region us-central1 --project dw-genai-dev --quiet

   gcloud run services delete weather-remote-mcp-server-adk-memory \
     --region us-central1 --project dw-genai-dev --quiet

   gcloud run services delete a2a-frontend-adk-memory \
     --region us-central1 --project dw-genai-dev --quiet
   ```

6. **Delete old agent engines**:
   ```bash
   # List agent engines
   gcloud ai reasoning-engines list \
     --region us-central1 \
     --project dw-genai-dev

   # Delete old agents (get IDs from list command)
   gcloud ai reasoning-engines delete COCKTAIL_AGENT_ID \
     --region us-central1 --project dw-genai-dev

   gcloud ai reasoning-engines delete WEATHER_AGENT_ID \
     --region us-central1 --project dw-genai-dev

   gcloud ai reasoning-engines delete HOSTING_AGENT_ID \
     --region us-central1 --project dw-genai-dev
   ```

### Option 2: In-Place Update

Update services in place (requires manual steps).

**Advantages**:
- Keeps same service IDs
- Less cleanup needed

**Disadvantages**:
- Cannot change Cloud Run service names in-place
- Would require delete and recreate anyway

**Conclusion**: Not recommended - use Option 1 instead.

### Option 3: Gradual Migration

Migrate one component at a time.

**Steps**:

1. **Week 1**: Deploy new MCP servers only
2. **Week 2**: Deploy new agents pointing to new MCP servers
3. **Week 3**: Deploy new frontend
4. **Week 4**: Clean up old services

**Conclusion**: Only use if you need to minimize disruption.

## Terraform State Management

### Current Terraform State

The CI/CD pipeline imports existing services into Terraform state:

```yaml
# From .github/workflows/deploy.yml
terraform import google_cloud_run_v2_service.cocktail_mcp_server \
  "projects/.../services/cocktail-remote-mcp-server-adk-memory"
```

### After Migration

After deploying with new names, the imports will fail (service names don't match). This is expected and safe because:

1. **New services** don't exist yet, so import fails (expected)
2. **Terraform create** runs and creates new services
3. **Old services** remain untouched until you delete them

### Terraform Apply Behavior

When you run `terraform apply` after the naming change:

```
Plan: 3 to add, 0 to change, 0 to destroy

+ google_cloud_run_v2_service.cocktail_mcp_server (new)
+ google_cloud_run_v2_service.weather_mcp_server (new)
+ google_cloud_run_v2_service.a2a_frontend (new)
```

This is correct - it will create new services.

## CI/CD Pipeline Behavior

The updated CI/CD pipeline (`.github/workflows/deploy.yml`) will:

1. ✅ Build images with "adk-mb" tags
2. ✅ Deploy Cloud Run services with "adk-mb" names
3. ✅ Deploy agents with "adk-mb" display names
4. ✅ Configure environment variables to point to new services
5. ⚠️ Try to import old services (will fail - expected)
6. ✅ Create new services via `terraform apply`

## Checklist

### Pre-Migration
- [ ] Review all code changes
- [ ] Update `.env` files if needed
- [ ] Backup current service configurations
- [ ] Document current service URLs

### Migration
- [ ] Push code to staging branch
- [ ] Monitor CI/CD pipeline
- [ ] Verify new services are created
- [ ] Test new services
- [ ] Update environment variables

### Post-Migration
- [ ] Verify all tests pass
- [ ] Update external references
- [ ] Delete old Cloud Run services
- [ ] Delete old agent engines
- [ ] Update documentation
- [ ] Clean up Terraform state (optional)

## Cost Considerations

During migration, you'll have **both old and new services** running:
- 2x Cloud Run services (MCP servers + frontend)
- 2x Agent Engines (3 agents each)

**Recommendation**: Complete migration within **24 hours** to minimize double costs.

## Rollback Plan

If new services don't work:

1. **Keep old services running** (don't delete yet)
2. **Update environment variables** to point back to old services
3. **Investigate issues** with new deployment
4. **Fix and redeploy** when ready

## Verification

After migration, verify:

```bash
# Check new services exist
gcloud run services list --region us-central1 --project dw-genai-dev | grep adk-mb

# Check new agents exist
gcloud ai reasoning-engines list --region us-central1 --project dw-genai-dev | grep "adk-mb"

# Test frontend
curl https://a2a-frontend-adk-mb-496235138247.us-central1.run.app

# Run integration tests
python tests/integration/test_hosting_agent_remote.py
```

## Support

If you encounter issues:
- Check CI/CD logs in GitHub Actions
- Review Cloud Console: Cloud Run > Services
- Check Agent Engine status: Vertex AI > Agent Builder
- Review error messages in Cloud Logging

## Timeline

Recommended migration timeline:

- **T+0**: Push code to staging
- **T+10min**: CI/CD completes, new services deployed
- **T+20min**: Test new services
- **T+30min**: Verify everything works
- **T+1hr**: Delete old services (if confident)
- **T+24hr**: Monitor for issues

## Status Tracking

Use this checklist to track migration progress:

- [ ] Code updated with "adk-mb" naming
- [ ] Pushed to staging branch
- [ ] CI/CD pipeline completed successfully
- [ ] New MCP servers deployed and tested
- [ ] New agents deployed and tested
- [ ] New frontend deployed and tested
- [ ] All integration tests pass
- [ ] Old MCP servers deleted
- [ ] Old agents deleted
- [ ] Old frontend deleted
- [ ] Documentation updated
- [ ] Migration complete ✅
