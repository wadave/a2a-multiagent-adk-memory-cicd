# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Stores the Hosting Agent Engine resource name so the frontend can resolve it
# at startup without a hard dependency on the Terraform variable.
# The CI/CD pipeline writes the real value after each agent deployment via:
#   gcloud secrets versions add agent-engine-id --data-file=-
resource "google_secret_manager_secret" "agent_engine_id" {
  secret_id = "agent-engine-id"
  project   = var.cicd_runner_project_id

  replication {
    auto {}
  }
}

# Seed version with a placeholder so the secret exists on first apply.
# CI/CD overwrites this with the real value; lifecycle.ignore_changes
# prevents Terraform from reverting those updates.
resource "google_secret_manager_secret_version" "agent_engine_id_initial" {
  secret      = google_secret_manager_secret.agent_engine_id.id
  secret_data = "unset"

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# Grant the default compute service account read access to this specific secret.
# The frontend Cloud Run service runs as this identity.
resource "google_secret_manager_secret_iam_member" "frontend_secret_accessor" {
  secret_id = google_secret_manager_secret.agent_engine_id.secret_id
  project   = var.cicd_runner_project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}
