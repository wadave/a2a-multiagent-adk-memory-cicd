terraform {
  backend "gcs" {
    bucket = "dw-genai-dev-terraform-state"
    prefix = "a2a-multiagent-adk-memory-cicd/prod"
  }
}
