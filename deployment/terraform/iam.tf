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

# Grant the CI/CD service account Model Armor Admin to manage floor settings.
resource "google_project_iam_member" "github_runner_modelarmor_admin" {
  project = var.deploy_project_id
  role    = "roles/modelarmor.admin"
  member  = "serviceAccount:github-runner@${var.cicd_runner_project_id}.iam.gserviceaccount.com"
}

# roles/modelarmor.admin does NOT include resourcemanager.projects.get, which
# every gcloud command needs to validate the target project.
# roles/browser is the minimal project-assignable role that includes
# resourcemanager.projects.get without any write or service-specific access.
# (roles/resourcemanager.projectViewer is org/folder-level only and cannot
# be granted at the project level.)
resource "google_project_iam_member" "github_runner_browser" {
  project = var.deploy_project_id
  role    = "roles/browser"
  member  = "serviceAccount:github-runner@${var.cicd_runner_project_id}.iam.gserviceaccount.com"
}

# Grant the CI/CD service account token accessor to fetch source from Developer Connect / Cloud Build Connections.
resource "google_project_iam_member" "github_runner_token_accessor" {
  project = var.deploy_project_id
  role    = "roles/cloudbuild.readTokenAccessor"
  member  = "serviceAccount:github-runner@${var.cicd_runner_project_id}.iam.gserviceaccount.com"
}

# Grant the CI/CD service account Service Usage Consumer so that Workload Identity
# Federation credentials can use the project as a quota/billing project.
# Without this, newer GCP APIs reject calls from external credentials with
# PERMISSION_DENIED even when the service account has the API-specific role.
resource "google_project_iam_member" "github_runner_serviceusage_consumer" {
  project = var.deploy_project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:github-runner@${var.cicd_runner_project_id}.iam.gserviceaccount.com"
}
