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
"""Centralized configuration for A2A integration tests."""

import os

from dotenv import load_dotenv

# Ensure environment variables are loaded for tests
load_dotenv()

# Common Google Cloud Configurations
PROJECT_ID = os.environ.get("PROJECT_ID", "dw-genai-dev")
LOCATION = os.environ.get("GOOGLE_CLOUD_REGION", "us-central1")
PROJECT_NUMBER = os.environ.get("PROJECT_NUMBER", "496235138247")

# Agent IDs
HOSTING_AGENT_ID = os.environ.get("HOSTING_AGENT_ID", "2417983299642195968")
COCKTAIL_AGENT_ID = os.environ.get("COCKTAIL_AGENT_ID", "2016037032899379200")
WEATHER_AGENT_ID = os.environ.get("WEATHER_AGENT_ID", "4182268453664587776")

# Remote Cocktail MCP Server URL (used by local and monkeypatch tests)
CT_MCP_SERVER_URL = os.environ.get(
    "CT_MCP_SERVER_URL",
    "https://cocktail-remote-mcp-server-adk-mb-lxo6yz2aha-uc.a.run.app",
)

# Remote Weather MCP Server URL (used by integration tests)
WEA_MCP_SERVER_URL = os.environ.get(
    "WEA_MCP_SERVER_URL",
    "https://weather-remote-mcp-server-adk-mb-lxo6yz2aha-uc.a.run.app",
)
