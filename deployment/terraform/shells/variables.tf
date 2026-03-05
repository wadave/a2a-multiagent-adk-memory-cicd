variable "deploy_project_id" {
  description = "GCP project ID for the target deployment environment"
  type        = string
}

variable "region" {
  description = "GCP region for resource deployment"
  type        = string
  default     = "us-central1"
}

variable "project_number" {
  description = "GCP project number"
  type        = string
  default     = ""
}

variable "agent_engine_id" {
  description = "The deployed AGENT_ENGINE_ID from deploy_agents.py (e.g. projects/123/locations/us-central1/reasoningEngines/456)"
  type        = string

  validation {
    condition     = can(regex("^projects/[0-9]+/locations/[a-z0-9-]+/reasoningEngines/[0-9]+$", var.agent_engine_id))
    error_message = "agent_engine_id must be a valid Vertex AI Reasoning Engine resource name (projects/{number}/locations/{region}/reasoningEngines/{id})."
  }
}

variable "oauth_client_id_secret_name" {
  description = "The name of the Secret in Secret Manager containing the Gemini Enterprise OAuth Client Credentials JSON payload"
  type        = string
  default     = ""
}

variable "ge_app_staging" {
  description = "Gemini Enterprise App ID for staging"
  type        = string
  default     = ""
}

variable "ge_app_prod" {
  description = "Gemini Enterprise App ID for production"
  type        = string
  default     = ""
}

variable "agents_region" {
  description = "Region for Gemini Enterprise (Discovery Engine API location). Use 'global' for GE apps created in global scope."
  type        = string
  default     = "global"
}

variable "auth_id" {
  description = "The ID of the Gemini Enterprise authorization account (must be unique per agent project)"
  type        = string
  default     = "a2a_adk_mb_oauth_token_v1"
}
