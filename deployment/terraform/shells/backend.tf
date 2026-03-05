terraform {
  backend "gcs" {
    # Bucket and prefix are configured dynamically via CLI flags in CI/CD.
    # Uses a separate prefix from the main infra root to isolate state.
    # Example:
    #   terraform init \
    #     -backend-config="bucket=PROJECT_ID-terraform-state" \
    #     -backend-config="prefix=a2a-multiagent-adk-memory-cicd/staging-shells"
  }
}
