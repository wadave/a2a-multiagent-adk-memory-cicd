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
  for_each           = local.deploy_project_ids
  project            = each.value
  service            = "modelarmor.googleapis.com"
  disable_on_destroy = false
}

resource "null_resource" "model_armor_floor_settings" {
  for_each = local.deploy_project_ids

  provisioner "local-exec" {
    command = <<EOT
      gcloud model-armor floorsettings update \
        --full-uri=projects/${each.value}/locations/global/floorSetting \
        --enable-floor-setting-enforcement=TRUE \
        --add-integrated-services=VERTEX_AI \
        --vertex-ai-enforcement-type=INSPECT_AND_BLOCK \
        --enable-vertex-ai-cloud-logging \
        --pi-and-jailbreak-filter-settings-enforcement=enable \
        --pi-and-jailbreak-filter-settings-confidence-level=low-and-above \
        --malicious-uri-filter-settings-enforcement=ENABLED \
        --rai-settings-filters="confidenceLevel=LOW_AND_ABOVE,filterType=HATE_SPEECH","confidenceLevel=LOW_AND_ABOVE,filterType=DANGEROUS","confidenceLevel=LOW_AND_ABOVE,filterType=SEXUALLY_EXPLICIT","confidenceLevel=LOW_AND_ABOVE,filterType=HARASSMENT" \
        --project=${each.value}
    EOT
  }

  depends_on = [
    google_project_service.modelarmor_api
  ]
}
