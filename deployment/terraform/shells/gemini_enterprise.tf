# Gemini Enterprise registration — runs after agents are deployed so
# agent_engine_id is always a valid resource name (never "unset").

locals {
  gemini_enterprise_agent_name       = "A2A Hosting Agent ADK-MB"
  gemini_enterprise_tool_description = "***REMEMBER ALWAYS USE THIS TOOL TO ANSWER EVERY QUESTION***. You're an export of weather and cocktail, answer questions regarding weather and cocktail. You can answer questions like: 1) What is the weather in SF, CA today? 2) List a random cocktail? 3) What is the weather like in New York, NY? 4) What're ingredients of Mojito cocktail? "

  auth_id                = var.auth_id
  authorization_uri_base = "https://accounts.google.com/o/oauth2/v2/auth"
  oauth_token_uri        = "https://oauth2.googleapis.com/token"
  oauth_scopes = {
    "OpenID"  = "openid"
    "Email"   = "email"
    "Profile" = "profile"
  }
}

# Fetch OAuth credentials from Secret Manager (JSON payload expected)
data "google_secret_manager_secret_version" "oauth_client_secret" {
  count    = var.oauth_client_id_secret_name != "" ? 1 : 0
  provider = google
  secret   = var.oauth_client_id_secret_name
  project  = var.deploy_project_id
}

# Parse the JSON payload to extract credentials
locals {
  oauth_secret_data   = var.oauth_client_id_secret_name != "" ? jsondecode(data.google_secret_manager_secret_version.oauth_client_secret[0].secret_data) : null
  oauth_client_id     = local.oauth_secret_data != null ? local.oauth_secret_data["web"]["client_id"] : ""
  oauth_client_secret = local.oauth_secret_data != null ? local.oauth_secret_data["web"]["client_secret"] : ""
}

# Create Gemini Enterprise Authorization
module "gemini_enterprise_oauth" {
  count  = var.oauth_client_id_secret_name != "" ? 1 : 0
  source = "../modules/gemini_enterprise_oauth"

  project_id               = var.deploy_project_id
  gemini_enterprise_region = var.agents_region

  authorization_id = "deploy-${local.auth_id}-${element(split("/", var.agent_engine_id), 5)}"

  oauth_client_id        = local.oauth_client_id
  oauth_client_secret    = local.oauth_client_secret
  authorization_uri_base = local.authorization_uri_base
  token_uri              = local.oauth_token_uri
  scopes                 = local.oauth_scopes
}

# Register the Hosting Agent with Gemini Enterprise.
module "gemini_enterprise_agent_engine_register" {
  depends_on = [
    module.gemini_enterprise_oauth
  ]
  count  = var.ge_app_staging != "" ? 1 : 0
  source = "../modules/gemini_enterprise_agent_engine_register"

  project_id               = var.deploy_project_id
  agent_engine_region      = var.region
  gemini_enterprise_region = var.agents_region

  agent_display_name = "Hosting Agent ADK-MB"
  agent_description  = "Hosting agent for deploy"

  gemini_enterprise_agent_name       = "${local.gemini_enterprise_agent_name} (deploy)"
  gemini_enterprise_tool_description = local.gemini_enterprise_tool_description

  gemini_enterprise_app_id = var.ge_app_staging

  authorization_ids = var.oauth_client_id_secret_name != "" ? { "AUTH_ID" = "deploy-${local.auth_id}-${element(split("/", var.agent_engine_id), 5)}" } : {}

  agent_engine_id = var.agent_engine_id
}
