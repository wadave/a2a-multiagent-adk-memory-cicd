#!/usr/bin/env bash
# Local test script for GE registration step only.
# Mirrors the CI/CD "Terraform Apply Gemini Enterprise Registration" step.
#
# Prerequisites:
#   - terraform installed
#   - gcloud authenticated (gcloud auth application-default login)
#
# Required env vars (or edit the defaults below):
#   GE_APP_STAGING              - Gemini Enterprise app ID for staging
#   OAUTH_CLIENT_ID_SECRET_NAME - Secret Manager secret name for OAuth credentials
#
# Optional overrides:
#   PROJECT_ID      (default: dw-genai-dev)
#   PROJECT_NUMBER  (default: 496235138247)
#   REGION          (default: us-central1)
#   AGENTS_REGION   (default: global)

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-dw-genai-dev}"
PROJECT_NUMBER="${PROJECT_NUMBER:-496235138247}"
REGION="${REGION:-us-central1}"
AGENTS_REGION="${AGENTS_REGION:-global}"
TF_DIR="$(dirname "$0")/terraform"

# Validate required vars
if [ -z "${GE_APP_STAGING:-}" ]; then
  echo "ERROR: GE_APP_STAGING is not set."
  echo "  export GE_APP_STAGING=<your-ge-app-id>"
  exit 1
fi

if [ -z "${OAUTH_CLIENT_ID_SECRET_NAME:-}" ]; then
  echo "ERROR: OAUTH_CLIENT_ID_SECRET_NAME is not set."
  echo "  export OAUTH_CLIENT_ID_SECRET_NAME=<your-secret-name>"
  exit 1
fi

echo "=== Config ==="
echo "  PROJECT_ID:                 $PROJECT_ID"
echo "  PROJECT_NUMBER:             $PROJECT_NUMBER"
echo "  REGION:                     $REGION"
echo "  AGENTS_REGION:              $AGENTS_REGION"
echo "  GE_APP_STAGING:             $GE_APP_STAGING"
echo "  OAUTH_CLIENT_ID_SECRET_NAME: $OAUTH_CLIENT_ID_SECRET_NAME"
echo ""

# Step 1: Look up agent engine ID
echo "=== Looking up Hosting Agent engine ID ==="
TOKEN=$(gcloud auth print-access-token)
AGENT_ENGINE_ID=$(curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT_ID}/locations/${REGION}/reasoningEngines?pageSize=100" \
  | jq -r '.reasoningEngines[]? | select(.displayName == "Hosting Agent ADK-MB") | .name' \
  | head -1)

if [ -z "$AGENT_ENGINE_ID" ]; then
  echo "ERROR: Could not find 'Hosting Agent ADK-MB' in project $PROJECT_ID / region $REGION."
  echo "Make sure the agent is deployed and you are authenticated to the correct project."
  exit 1
fi
echo "Found agent engine: $AGENT_ENGINE_ID"
echo ""

# Step 2: Terraform init
echo "=== Terraform init ==="
terraform -chdir="$TF_DIR" init \
  -backend-config="bucket=${PROJECT_ID}-terraform-state" \
  -backend-config="prefix=a2a-multiagent-adk-memory-cicd/staging" \
  -reconfigure
echo ""

# Step 3: Terraform apply — GE modules only
echo "=== Terraform apply (GE modules only) ==="
terraform -chdir="$TF_DIR" apply -auto-approve \
  -var="cicd_runner_project_id=${PROJECT_ID}" \
  -var="staging_project_id=${PROJECT_ID}" \
  -var="prod_project_id=${PROJECT_ID}" \
  -var="project_number=${PROJECT_NUMBER}" \
  -var="repository_name=a2a-multiagent-adk-memory-cicd" \
  -var="repository_owner=wadave" \
  -var="agent_engine_id=${AGENT_ENGINE_ID}" \
  -var="ge_app_staging=${GE_APP_STAGING}" \
  -var="oauth_client_id_secret_name=${OAUTH_CLIENT_ID_SECRET_NAME}" \
  -var="agents_region=${AGENTS_REGION}" \
  -target=module.gemini_enterprise_oauth \
  -target=module.gemini_enterprise_agent_engine_register

echo ""
echo "=== GE registration complete ==="
