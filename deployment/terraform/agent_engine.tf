# Hybrid Provisioning: Terraform creates Agent Engine shells with dummy source
# code. CI/CD then updates them with real application code via the Python SDK
# (deploy_agents.py). The lifecycle block prevents Terraform from reverting
# SDK-managed source code updates.

locals {
  # Display names must match agent_card.agent_name in src/a2a_agents/*/
  # so that deploy_agents.py can find and update the correct shell.
  agent_engines = {
    cocktail = {
      display_name = "Cocktail Agent ADK-MB"
      description  = "Cocktail domain agent (A2A) deployed via Terraform"
    }
    weather = {
      display_name = "Weather Agent ADK-MB"
      description  = "Weather domain agent (A2A) deployed via Terraform"
    }
    hosting = {
      display_name = "Hosting Agent ADK-MB"
      description  = "Hosting orchestrator agent (ADK) deployed via Terraform"
    }
  }

  # Read the base64-encoded dummy source tarball from a local file.
  # This avoids a dependency on any public GCS bucket.
  dummy_source_b64 = trimspace(file("${path.module}/dummy/source-b64.txt"))
}

resource "google_vertex_ai_reasoning_engine" "agent" {
  for_each = local.agent_engines

  display_name = each.value.display_name
  description  = each.value.description
  region       = var.region
  project      = var.cicd_runner_project_id

  spec {
    agent_framework = "google-adk"

    deployment_spec {
      min_instances         = 1
      max_instances         = 10
      container_concurrency = 9

      resource_limits = {
        cpu    = "4"
        memory = "8Gi"
      }

      env {
        name  = "GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY"
        value = "true"
      }
    }

    source_code_spec {
      inline_source {
        source_archive = local.dummy_source_b64
      }

      python_spec {
        entrypoint_module = "app.agent_engine_app"
        entrypoint_object = "agent_engine"
        requirements_file = "app/app_utils/.requirements.txt"
        version           = "3.12"
      }
    }
  }

  # Prevent Terraform from overwriting source code updated by deploy_agents.py
  lifecycle {
    ignore_changes = [
      spec[0].source_code_spec,
      spec[0].package_spec,
      spec[0].deployment_spec,
      display_name
    ]
  }
}
