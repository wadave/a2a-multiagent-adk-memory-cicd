# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_project_service" "modelarmor_api" {
  project            = var.deploy_project_id
  service            = "modelarmor.googleapis.com"
  disable_on_destroy = false
}

# IAM propagation can take 60-120 s after the API returns success.
# With a single terraform apply all IAM members and this provisioner run
# in the same plan, so we must wait long enough before attempting the
# gcloud call.  120 s covers the documented worst-case propagation time
# for most regions; the retry loop below adds another 3 minutes of buffer.
resource "time_sleep" "wait_for_modelarmor_admin_iam" {
  create_duration = "120s"

  depends_on = [
    google_project_iam_member.github_runner_modelarmor_admin,
    google_project_iam_member.github_runner_serviceusage_consumer,
    google_project_iam_member.github_runner_token_accessor,
    google_project_service.modelarmor_api,
  ]
}

resource "null_resource" "model_armor_floor_settings" {
  provisioner "local-exec" {
    command = <<EOT
      for i in $(seq 1 18); do
        if gcloud model-armor floorsettings update \
          --full-uri=projects/${var.deploy_project_id}/locations/global/floorSetting \
          --enable-floor-setting-enforcement=TRUE \
          --add-integrated-services=VERTEX_AI \
          --vertex-ai-enforcement-type=INSPECT_AND_BLOCK \
          --enable-vertex-ai-cloud-logging \
          --pi-and-jailbreak-filter-settings-enforcement=enable \
          --pi-and-jailbreak-filter-settings-confidence-level=low-and-above \
          --malicious-uri-filter-settings-enforcement=ENABLED \
          --rai-settings-filters="confidenceLevel=LOW_AND_ABOVE,filterType=HATE_SPEECH","confidenceLevel=LOW_AND_ABOVE,filterType=DANGEROUS","confidenceLevel=LOW_AND_ABOVE,filterType=SEXUALLY_EXPLICIT","confidenceLevel=LOW_AND_ABOVE,filterType=HARASSMENT" \
          --project=${var.deploy_project_id}; then
          echo "Successfully updated floor settings"
          exit 0
        fi
        echo "Waiting for IAM permissions to propagate... (Attempt $i/18)"
        sleep 10
      done
      echo "Failed to update floor settings after multiple attempts"
      exit 1
    EOT
  }

  depends_on = [
    time_sleep.wait_for_modelarmor_admin_iam,
  ]
}
