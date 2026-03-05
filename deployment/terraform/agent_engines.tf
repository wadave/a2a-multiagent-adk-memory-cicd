# Provision Dummy Agent Engines so they are tracked by Terraform
# CI/CD (deploy_agents.py) will dynamically update these shells with the actual codebase.

# Fetch the dummy source archive from the starter pack
data "google_storage_bucket_object_content" "dummy_source_b64" {
  name   = "dummy/source-b64.txt"
  bucket = "agent-starter-pack"
}

locals {
  agent_service_account = "${var.project_number}-compute@developer.gserviceaccount.com"
}

resource "google_vertex_ai_reasoning_engine" "cocktail_agent" {
  display_name = "Cocktail ADK Agent"
  description  = "Agent deployed via Terraform"
  region       = var.region
  project      = var.deploy_project_id

  spec {
    agent_framework = "google-adk"
    service_account = local.agent_service_account

    deployment_spec {
      min_instances         = 1
      max_instances         = 10
      container_concurrency = 9

      resource_limits = {
        cpu    = "4"
        memory = "8Gi"
      }
    }

    source_code_spec {
      inline_source {
        source_archive = trimspace(data.google_storage_bucket_object_content.dummy_source_b64.content)
      }

      python_spec {
        entrypoint_module = "app.agent_engine_app"
        entrypoint_object = "agent_engine"
        requirements_file = "app/app_utils/.requirements.txt"
        version           = "3.12"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].source_code_spec,
      spec[0].deployment_spec[0].env,
      description
    ]
  }
}

resource "google_vertex_ai_reasoning_engine" "weather_agent" {
  display_name = "Weather ADK Agent"
  description  = "Agent deployed via Terraform"
  region       = var.region
  project      = var.deploy_project_id

  spec {
    agent_framework = "google-adk"
    service_account = local.agent_service_account

    deployment_spec {
      min_instances         = 1
      max_instances         = 10
      container_concurrency = 9

      resource_limits = {
        cpu    = "4"
        memory = "8Gi"
      }
    }

    source_code_spec {
      inline_source {
        source_archive = trimspace(data.google_storage_bucket_object_content.dummy_source_b64.content)
      }

      python_spec {
        entrypoint_module = "app.agent_engine_app"
        entrypoint_object = "agent_engine"
        requirements_file = "app/app_utils/.requirements.txt"
        version           = "3.12"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].source_code_spec,
      spec[0].deployment_spec[0].env,
      description
    ]
  }
}

resource "google_vertex_ai_reasoning_engine" "hosting_agent" {
  display_name = "Hosting ADK Agent"
  description  = "Agent deployed via Terraform"
  region       = var.region
  project      = var.deploy_project_id

  spec {
    agent_framework = "google-adk"
    service_account = local.agent_service_account

    deployment_spec {
      min_instances         = 1
      max_instances         = 10
      container_concurrency = 9

      resource_limits = {
        cpu    = "4"
        memory = "8Gi"
      }
    }

    source_code_spec {
      inline_source {
        source_archive = trimspace(data.google_storage_bucket_object_content.dummy_source_b64.content)
      }

      python_spec {
        entrypoint_module = "app.agent_engine_app"
        entrypoint_object = "agent_engine"
        requirements_file = "app/app_utils/.requirements.txt"
        version           = "3.12"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].source_code_spec,
      spec[0].deployment_spec[0].env,
      description
    ]
  }
}
