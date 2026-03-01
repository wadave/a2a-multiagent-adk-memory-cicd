# IAM Policy Bindings for Cloud Run Services

# Grant compute service account permission to invoke MCP servers
# This is needed for Agent Engines to call MCP servers
data "google_project" "project" {
  project_id = var.cicd_runner_project_id
}

resource "google_cloud_run_v2_service_iam_member" "cocktail_mcp_compute_invoker" {
  name     = google_cloud_run_v2_service.cocktail_mcp_server.name
  location = google_cloud_run_v2_service.cocktail_mcp_server.location
  project  = var.cicd_runner_project_id
  role     = "roles/run.invoker"
  member   = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_cloud_run_v2_service_iam_member" "weather_mcp_compute_invoker" {
  name     = google_cloud_run_v2_service.weather_mcp_server.name
  location = google_cloud_run_v2_service.weather_mcp_server.location
  project  = var.cicd_runner_project_id
  role     = "roles/run.invoker"
  member   = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Allow frontend to be publicly accessible
resource "google_cloud_run_v2_service_iam_member" "frontend_invoker" {
  name     = google_cloud_run_v2_service.a2a_frontend.name
  location = google_cloud_run_v2_service.a2a_frontend.location
  project  = var.cicd_runner_project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Grant the CI/CD service account Model Armor Admin to manage floor settings
resource "google_project_iam_member" "github_runner_modelarmor_admin" {
  project = var.deploy_project_id
  role    = "roles/modelarmor.admin"
  member  = "serviceAccount:github-runner@${var.cicd_runner_project_id}.iam.gserviceaccount.com"
}

# Grant the CI/CD service account token accessor to fetch source from Developer Connect / Cloud Build Connections
resource "google_project_iam_member" "github_runner_token_accessor" {
  project = var.deploy_project_id
  role    = "roles/cloudbuild.readTokenAccessor"
  member  = "serviceAccount:github-runner@${var.cicd_runner_project_id}.iam.gserviceaccount.com"
}
