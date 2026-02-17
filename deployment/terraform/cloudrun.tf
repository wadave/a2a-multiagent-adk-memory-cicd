# Cloud Run Service for Cocktail MCP Server
resource "google_cloud_run_v2_service" "cocktail_mcp_server" {
  deletion_protection = false
  name     = "cocktail-remote-mcp-server-adk-mb"
  location = var.region
  project  = var.cicd_runner_project_id

  template {
    timeout = "300s"
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      
      resources {
        limits = {
          cpu    = "1000m"
          memory = "1024Mi"
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# Cloud Run Service for Weather MCP Server
resource "google_cloud_run_v2_service" "weather_mcp_server" {
  deletion_protection = false
  name     = "weather-remote-mcp-server-adk-mb"
  location = var.region
  project  = var.cicd_runner_project_id

  template {
    timeout = "300s"
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      
      resources {
        limits = {
          cpu    = "1000m"
          memory = "1024Mi"
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# Cloud Run Service for the A2A Frontend
resource "google_cloud_run_v2_service" "a2a_frontend" {
  deletion_protection = false
  name     = "a2a-frontend-adk-mb"
  location = var.region
  project  = var.cicd_runner_project_id

  template {
    timeout = "300s"
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      
      env {
        name  = "AGENT_ENGINE_ID"
        # This will be injected dynamically if deploying agents outside Terraform,
        # or replaced by a known value if deployed within Terraform
        value = var.agent_engine_id
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "2048Mi"
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}
 
