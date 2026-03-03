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

# Propagate non-sensitive configuration values as GitHub Actions environment
# variables so that CI/CD runs correctly without any manual GitHub setup.
# Requires GITHUB_TOKEN in the local environment when running `terraform apply`.

# Ensure GitHub Actions environments exist before creating variables in them.
resource "github_repository_environment" "staging" {
  repository  = var.repository_name
  environment = "staging"
}

resource "github_repository_environment" "main" {
  repository  = var.repository_name
  environment = "main"
}

resource "github_actions_environment_variable" "ge_app_staging" {
  depends_on    = [github_repository_environment.staging]
  count         = var.ge_app_staging != "" ? 1 : 0
  repository    = var.repository_name
  environment   = "staging"
  variable_name = "GE_APP_STAGING"
  value         = var.ge_app_staging
}

resource "github_actions_environment_variable" "ge_app_prod" {
  depends_on    = [github_repository_environment.main]
  count         = var.ge_app_prod != "" ? 1 : 0
  repository    = var.repository_name
  environment   = "main"
  variable_name = "GE_APP_PROD"
  value         = var.ge_app_prod
}

resource "github_actions_environment_variable" "oauth_client_id_secret_name" {
  depends_on    = [github_repository_environment.staging]
  count         = var.oauth_client_id_secret_name != "" ? 1 : 0
  repository    = var.repository_name
  environment   = "staging"
  variable_name = "OAUTH_CLIENT_ID_SECRET_NAME"
  value         = var.oauth_client_id_secret_name
}
