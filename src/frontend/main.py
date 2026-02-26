# Copyright 2025 Google LLC
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
"""A Gradio-based web interface for interacting with a remote A2A agent.

This application provides a chat interface that allows users to send queries to
a hosting agent running on Vertex AI. It handles authentication with Google
Cloud, creates an A2A (Agent-to-Agent) client, and streams responses back to the
user interface.
"""

import asyncio
import logging
import os
import traceback
from typing import Any, AsyncIterator, List

import gradio as gr
import httpx
import vertexai
from a2a.client import Client, ClientConfig, ClientFactory
from a2a.types import (
    Message,
    Part,
    Role,
    TaskState,
    TextPart,
    TransportProtocol,
)
from dotenv import load_dotenv
from google.auth import default
from google.auth.transport.requests import Request as AuthRequest
from google.genai import types as genai_types

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("a2a-frontend")

load_dotenv()

PROJECT_ID = os.getenv("PROJECT_ID")
PROJECT_NUMBER = os.getenv("PROJECT_NUMBER")
AGENT_ENGINE_ID = os.getenv("AGENT_ENGINE_ID")
LOCATION = os.getenv("LOCATION") or os.getenv("GOOGLE_CLOUD_LOCATION") or "us-central1"


# Initialize Vertex AI session
vertexai.init(project=PROJECT_ID, location=LOCATION)

client = vertexai.Client(
    project=PROJECT_ID,
    location=LOCATION,
    http_options=genai_types.HttpOptions(
        api_version="v1beta1", base_url=f"https://{LOCATION}-aiplatform.googleapis.com/"
    ),
)


if AGENT_ENGINE_ID and "/" in AGENT_ENGINE_ID:
    remote_a2a_agent_resource_name = AGENT_ENGINE_ID
else:
    remote_a2a_agent_resource_name = f"projects/{PROJECT_NUMBER}/locations/{LOCATION}/reasoningEngines/{AGENT_ENGINE_ID}"


class GoogleAuth(httpx.Auth):
    """A custom httpx Auth class for Google Cloud authentication."""

    def __init__(self):
        self.credentials, self.project = default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        self.auth_request = AuthRequest()

    def auth_flow(self, request):
        if not self.credentials.valid:
            logger.info("Credentials expired, refreshing...")
            self.credentials.refresh(self.auth_request)

        request.headers["Authorization"] = f"Bearer {self.credentials.token}"
        yield request


# Global shared HTTP client for connection pooling
shared_httpx_client = httpx.AsyncClient(
    timeout=120,
    auth=GoogleAuth(),
)

# Cache for the agent card to avoid redundant network calls
_agent_card_cache: Any = None


async def get_agent_card(resource_name: str):
    """Fetches the agent card from Vertex AI (cached)."""
    global _agent_card_cache
    if _agent_card_cache is not None:
        return _agent_card_cache

    logger.info(f"Fetching agent card for {resource_name}...")
    config = {
        "http_options": {"base_url": f"https://LOCATION-aiplatform.googleapis.com"}
    }
    # Fix the template LOCATION variable if it was literally LOCATION
    actual_location = LOCATION or "us-central1"
    config["http_options"]["base_url"] = f"https://{actual_location}-aiplatform.googleapis.com"

    remote_a2a_agent = client.agent_engines.get(
        name=resource_name,
        config=config,
    )

    _agent_card_cache = await remote_a2a_agent.handle_authenticated_agent_card()
    logger.info("Agent card fetched and cached.")
    return _agent_card_cache


async def get_response_from_agent(
    query: str,
    history: List[gr.ChatMessage],
) -> AsyncIterator[gr.ChatMessage]:
    """Get response from host agent."""

    a2a_client: Client = None

    try:
        # --- 1. Get Agent Card (Cached) ---
        remote_a2a_agent_card = await get_agent_card(remote_a2a_agent_resource_name)

        # --- 2. Create A2A Client using global shared HTTP client ---
        factory = ClientFactory(
            ClientConfig(
                supported_transports=[TransportProtocol.http_json],
                use_client_preference=True,
                httpx_client=shared_httpx_client,
            )
        )

        a2a_client = factory.create(remote_a2a_agent_card)
        logger.info("A2A client created.")

        # --- 4. Create Message ---
        message = Message(
            message_id=f"message-{os.urandom(8).hex()}",
            role=Role.user,
            parts=[Part(root=TextPart(text=query))],
        )

        # --- 5. Send Message and Stream Response ---
        logger.info(f"Sending message to agent: {query}")
        response_stream = a2a_client.send_message(message)

        final_result_text = None

        async for response_chunk in response_stream:
            task_object = response_chunk[0]
            
            # Show status updates in the UI
            status_text = task_object.status.state.name if hasattr(task_object.status.state, "name") else str(task_object.status.state)
            yield gr.ChatMessage(role="assistant", content=f"*Agent status: {status_text}...*")

            if task_object.status.state == TaskState.completed:
                logger.info("Task completed. Checking for artifacts...")
                if hasattr(task_object, "artifacts") and task_object.artifacts:
                    for artifact in task_object.artifacts:
                        if artifact.parts and isinstance(
                            artifact.parts[0].root, TextPart
                        ):
                            final_result_text = artifact.parts[0].root.text
                            logger.info(f"Found artifact text: {final_result_text[:50]}...")
                            break
                if final_result_text:
                    break

            elif task_object.status.state == TaskState.failed:
                error_message = f"Task failed: {task_object.status.message if task_object.status else 'Unknown error'}"
                logger.error(error_message)
                yield gr.ChatMessage(role="assistant", content=error_message)
                return

        # --- 6. Yield Final Response ---
        if final_result_text:
            yield gr.ChatMessage(role="assistant", content=final_result_text)
        else:
            logger.warning("Task finished but no text artifact was found.")
            yield gr.ChatMessage(
                role="assistant",
                content="I processed your request but found no text response.",
            )

    except Exception as e:
        logger.error(f"Error in get_response_from_agent: {e}")
        logger.error(traceback.format_exc())
        yield gr.ChatMessage(
            role="assistant",
            content=f"An error occurred: {e}",
        )
    finally:
        if a2a_client:
            await a2a_client.close()
            logger.info("A2A client closed.")



async def main():
    """Main gradio app."""

    with gr.Blocks(theme=gr.themes.Ocean(), title="A2A Host Agent") as demo:
        with gr.Row():
            gr.Image(
                "static/a2a.png",
                width=100,
                height=100,
                scale=0,
                show_label=False,
                show_download_button=False,
                container=False,
                show_fullscreen_button=False,
            )

        gr.ChatInterface(
            get_response_from_agent,
            title="A2A Host Agent",
            description="This assistant can help you to check weather and find cocktail information",
        )

    logger.info("Launching Gradio interface on http://0.0.0.0:8080")
    demo.queue().launch(
        server_name="0.0.0.0",
        server_port=8080,
    )


if __name__ == "__main__":
    if not os.path.exists("static"):
        os.makedirs("static")
        logger.info("Created 'static' directory.")

    try:
        asyncio.run(main())
    finally:
        async def shutdown():
            await shared_httpx_client.aclose()
            logger.info("Shared HTTP client closed.")
        
        # Run shutdown if loop is already closed or still running
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                loop.create_task(shutdown())
            else:
                loop.run_until_complete(shutdown())
        except Exception:
            # Fallback if loop is already closed or if we are outside an async context
            try:
                asyncio.run(shutdown())
            except Exception:
                pass
