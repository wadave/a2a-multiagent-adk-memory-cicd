terraform {
  backend "gcs" {
    # Bucket and prefix are configured dynamically via CLI flags in CI/CD
    # Example:
    #   terraform init \
    #     -backend-config="bucket=PROJECT_ID-terraform-state" \
    #     -backend-config="prefix=a2a-multiagent-adk-memory-cicd/ENV"
    # where ENV is "staging" or "prod"
  }
}
