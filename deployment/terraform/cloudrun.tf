# Cloud Run Service for Cocktail MCP Server
resource "google_cloud_run_v2_service" "cocktail_mcp_server" {
  deletion_protection = false
  name     = "cocktail-remote-mcp-server-adk-mb"
  location = var.region
  project  = var.cicd_runner_project_id

  template {
    timeout = "300s"
    containers {
      image = "gcr.io/${var.cicd_runner_project_id}/cocktail-remote-mcp-server-adk-mb:latest"

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
      image = "gcr.io/${var.cicd_runner_project_id}/weather-remote-mcp-server-adk-mb:latest"

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
      image = "gcr.io/${var.cicd_runner_project_id}/a2a-frontend-adk-mb:latest"

      env {
        name  = "AGENT_ENGINE_ID"
        value = var.agent_engine_id
      }

      env {
        name  = "PROJECT_ID"
        value = var.cicd_runner_project_id
      }

      env {
        name  = "PROJECT_NUMBER"
        value = data.google_project.project.number
      }

      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = var.region
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
}
 
