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
import importlib
import logging
import os
import sys

from dotenv import load_dotenv

# Add src to path so that a2a_agents are importable
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../src")))

import vertexai
from vertexai._genai import _agent_engines_utils
from vertexai._genai.types import AgentEngineConfig

logging.basicConfig(level=logging.INFO)
logging.getLogger("httpx").setLevel(logging.WARNING)


def generate_class_methods(entrypoint_module: str, entrypoint_object: str) -> list[dict]:
    """Generate class_methods spec by importing the agent entrypoint."""
    module = importlib.import_module(entrypoint_module)
    agent_instance = getattr(module, entrypoint_object)
    registered_operations = _agent_engines_utils._get_registered_operations(agent=agent_instance)
    class_methods_spec = _agent_engines_utils._generate_class_methods_spec_or_raise(
        agent=agent_instance,
        operations=registered_operations,
    )
    return [_agent_engines_utils._to_dict(m) for m in class_methods_spec]


def find_existing_agent(client, display_name):
    """Find an existing agent engine by display_name. Returns resource name if found."""
    try:
        for agent_engine in client.agent_engines.list():
            engine_display_name = getattr(agent_engine.api_resource, "display_name", "") or getattr(
                agent_engine.api_resource, "displayName", ""
            )
            engine_name = getattr(agent_engine.api_resource, "name", "")
            if engine_display_name == display_name:
                logging.info(f"Found existing agent engine '{display_name}': {engine_name}")
                return engine_name
    except Exception as e:
        logging.warning(f"Could not list agent engines: {e}")
    return None


def deploy_agent(
    client,
    display_name: str,
    description: str,
    entrypoint_module: str,
    entrypoint_object: str,
    requirements_file: str,
    source_packages: list[str],
    env_vars: dict[str, str],
    project_number: str,
    service_account: str | None = None,
) -> str:
    """Deploy or update a single agent using source-based deployment.

    Uses source_code_spec (source_packages + entrypoint) instead of
    package_spec (pickle). This is compatible with Terraform-created
    Agent Engine shells that use source_code_spec.
    """
    # Vertex AI rejects empty string env var values
    env_vars = {k: v for k, v in env_vars.items() if v}

    logging.info(f"Deploying {display_name} to Agent Engine...")

    # Generate class_methods spec from the entrypoint
    try:
        class_methods = generate_class_methods(entrypoint_module, entrypoint_object)
    except Exception as e:
        logging.warning(f"Could not generate class_methods for {display_name}: {e}")
        class_methods = []

    sa = service_account or f"{project_number}-compute@developer.gserviceaccount.com"

    with open(requirements_file) as f:
        requirements = [
            line.strip() for line in f.readlines() if line.strip() and not line.startswith("#")
        ]

    config = AgentEngineConfig(
        display_name=display_name,
        description=description,
        source_packages=source_packages,
        entrypoint_module=entrypoint_module,
        entrypoint_object=entrypoint_object,
        class_methods=class_methods,
        env_vars=env_vars,
        service_account=sa,
        requirements=requirements,
    )

    existing_name = find_existing_agent(client, display_name)
    if existing_name:
        logging.info(f"Agent '{display_name}' already exists. Updating...")
        remote_agent = client.agent_engines.update(
            name=existing_name,
            config=config,
        )
        logging.info(f"Updated {display_name} successfully: {remote_agent.api_resource.name}")
        return remote_agent.api_resource.name

    remote_agent = client.agent_engines.create(config=config)

    # Vertex AI may ignore displayName on creation — patch it immediately.
    try:
        client.agent_engines.update(
            name=remote_agent.api_resource.name,
            config=AgentEngineConfig(
                display_name=display_name,
                description=description,
            ),
        )
        logging.info(f"Patched display name for {display_name}")
    except Exception as patch_e:
        logging.warning(f"Failed to patch display name for {display_name}: {patch_e}")

    logging.info(f"Deployed {display_name} successfully: {remote_agent.api_resource.name}")
    return remote_agent.api_resource.name


def main():
    # Change working directory to src so source_packages path resolves correctly
    src_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../src"))
    os.chdir(src_dir)
    logging.info(f"Changed working directory to {src_dir}")

    load_dotenv()

    project_id = os.environ.get("PROJECT_ID")
    location = os.environ.get("LOCATION") or os.environ.get("GOOGLE_CLOUD_REGION") or "us-central1"
    project_number = os.environ.get("PROJECT_NUMBER")
    google_genai_model = os.environ.get("GOOGLE_GENAI_MODEL", "gemini-2.5-flash")
    bucket_name = os.environ.get("BUCKET_NAME", f"{project_id}-bucket")

    if not project_id or not project_number:
        logging.error("PROJECT_ID and PROJECT_NUMBER must be set in environment.")
        sys.exit(1)

    ct_mcp_url = os.environ.get("CT_MCP_SERVER_URL")
    wea_mcp_url = os.environ.get("WEA_MCP_SERVER_URL")

    if not ct_mcp_url or not wea_mcp_url:
        logging.error("CT_MCP_SERVER_URL and WEA_MCP_SERVER_URL must be set in environment.")
        sys.exit(1)

    vertexai.init(project=project_id, location=location, staging_bucket=f"gs://{bucket_name}")
    client = vertexai.Client(project=project_id, location=location)

    # Requirements file is generated by CI/CD via `uv export` before this script runs.
    requirements_file = os.environ.get(
        "REQUIREMENTS_FILE",
        os.path.join(src_dir, ".requirements.txt"),
    )
    if not os.path.exists(requirements_file):
        logging.error(f"Requirements file not found: {requirements_file}. Run 'uv export' first.")
        sys.exit(1)

    source_packages = ["a2a_agents"]

    common_env = {
        "PROJECT_ID": project_id,
        "LOCATION": location,
        "BUCKET": bucket_name,
        "GOOGLE_GENAI_USE_VERTEXAI": "TRUE",
        "GOOGLE_GENAI_MODEL": google_genai_model,
        "DEBUG_MODE": "False",
    }

    # Deploy Cocktail Agent
    try:
        ct_agent_name = deploy_agent(
            client,
            display_name="Cocktail Agent ADK-MB",
            description="Cocktail domain agent (A2A)",
            entrypoint_module="a2a_agents.cocktail_agent.agent_engine_app",
            entrypoint_object="agent_engine",
            requirements_file=requirements_file,
            source_packages=source_packages,
            env_vars={**common_env, "CT_MCP_SERVER_URL": ct_mcp_url},
            project_number=project_number,
        )
    except Exception as e:
        logging.error(f"Failed to deploy Cocktail Agent: {e}")
        sys.exit(1)

    # Deploy Weather Agent
    try:
        wea_agent_name = deploy_agent(
            client,
            display_name="Weather Agent ADK-MB",
            description="Weather domain agent (A2A)",
            entrypoint_module="a2a_agents.weather_agent.agent_engine_app",
            entrypoint_object="agent_engine",
            requirements_file=requirements_file,
            source_packages=source_packages,
            env_vars={**common_env, "WEA_MCP_SERVER_URL": wea_mcp_url},
            project_number=project_number,
        )
    except Exception as e:
        logging.error(f"Failed to deploy Weather Agent: {e}")
        sys.exit(1)

    # Compute A2A URLs from deployed agent resource names
    ct_agent_url = f"https://{location}-aiplatform.googleapis.com/v1beta1/{ct_agent_name}/a2a"
    wea_agent_url = f"https://{location}-aiplatform.googleapis.com/v1beta1/{wea_agent_name}/a2a"

    # Deploy Hosting Agent (orchestrator)
    try:
        host_agent_name = deploy_agent(
            client,
            display_name="Hosting Agent ADK-MB",
            description="Hosting orchestrator agent (ADK)",
            entrypoint_module="a2a_agents.hosting_agent.agent_engine_app",
            entrypoint_object="agent_engine",
            requirements_file=requirements_file,
            source_packages=source_packages,
            env_vars={
                **common_env,
                "WEA_AGENT_URL": wea_agent_url,
                "CT_AGENT_URL": ct_agent_url,
            },
            project_number=project_number,
        )
    except Exception as e:
        logging.error(f"Failed to deploy Hosting Agent: {e}")
        sys.exit(1)

    logging.info("All agents deployed successfully.")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as f:
            f.write(f"AGENT_ENGINE_ID={host_agent_name}\n")
        logging.info("Exported AGENT_ENGINE_ID to GITHUB_OUTPUT.")


if __name__ == "__main__":
    main()
