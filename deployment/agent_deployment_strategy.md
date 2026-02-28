# Agent Engine Deployment Strategy

This document outlines the rationale behind our chosen deployment strategy for the Vertex AI Agent Engine (Reasoning Engine).

## Current Approach: Python SDK via CI/CD Script

Our project currently deploys agents using a dedicated Python script (`deployment/deploy_agents.py`) that leverages the `vertexai` and `google.genai` SDKs. This script is executed as a step within our Cloud Build/GitHub Actions CI/CD pipeline.

## Why Not Pure Terraform?

While HashiCorp provides a Google Cloud Provider resource for Reasoning Engine (`google_vertex_ai_reasoning_engine`), we deliberately chose the Python SDK approach for the following critical reasons:

### 1. The Packaging and Serialization Challenge

The Vertex AI Agent Engine requires the application code to be provided as a bundled, serialized object.
- **Python SDK (Cloudpickle):** The SDK automatically uses `cloudpickle` to traverse, serialize, and package your Python functions, classes, and their immediately required local module dependencies. It zips this up and manages the upload to a staging Google Cloud Storage (GCS) bucket natively.
- **Terraform:** Terraform is designed to manage declarative infrastructure, not to bundle and serialize application code. To use the `google_vertex_ai_reasoning_engine` resource, you must manually pre-package the `cloudpickle` object into a tarball and upload it to GCS (usually requiring complex `local-exec` bash scripts or separate pipeline steps) *before* Terraform can reference it.

### 2. Dependency Management (`requirements.txt`)

The Agent Engine builds an isolated container environment for your agent and requires an explicit list of pip dependencies to install at runtime.
- **Python SDK:** The `deploy_agents.py` script allows us to programmatically inject dependencies (e.g., passing a list of strings such as `["google-cloud-aiplatform", "a2a-sdk", "aiobreaker"]`) directly into the API payload. This provides flexibility, such as dynamically reading from a local `pyproject.toml` file or appending environment-specific packages during the build.
- **Terraform:** Managing a list of Python dependencies within Terraform variables creates a detachment from the actual Python project structure. It increases the risk of the "drift" we experienced (where `aiobreaker` was added to `pyproject.toml` but forgotten in the deployment configuration) because the infrastructure-as-code layer is decoupled from the application packaging layer.

### 3. Patching and Updates

The Reasoning Engine API has specific quirks, such as sometimes ignoring initial parameters (like `display_name`) during creation or requiring specific API versions (`v1beta1` with `HttpOptions`).
- **Python SDK:** A custom Python script grants us the imperative logic needed to immediately patch or `update()` the resource right after creation to enforce specific configurations and handle backend quirks gracefully (as seen in our `deploy_agents.py`).
- **Terraform:** Terraform's declarative nature makes it difficult to implement imperative "patching" logic. If a resource requires a two-step creation and update process due to API constraints, Terraform often struggles or requires complex lifecycle blocks that are challenging to maintain.

## Summary

Terraform is excellent for provisioning foundational infrastructure (like the underlying GCS buckets, IAM roles, Secret Manager, or enabling APIs like Model Armor). However, because deploying a Reasoning Engine fundamentally involves **application packaging, serialization, and dynamic dependency injection**, an imperative Python script executed via the CI/CD pipeline provides a vastly superior, less error-prone developer experience.
