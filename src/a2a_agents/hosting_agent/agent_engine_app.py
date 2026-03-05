"""Agent Engine entrypoint for Hosting Agent.

This module is referenced by source-based Agent Engine deployment.
The `agent_engine` object is the entrypoint that Agent Engine serves.

The Hosting Agent reads CT_AGENT_URL and WEA_AGENT_URL from environment
variables at executor initialization time (not at import time).
"""

from vertexai.preview.reasoning_engines import A2aAgent

from a2a_agents.hosting_agent.agent_executor import HostingAgentExecutor
from a2a_agents.hosting_agent.hosting_agent_card import hosting_agent_card

agent_engine = A2aAgent(
    agent_card=hosting_agent_card,
    agent_executor_builder=HostingAgentExecutor,
)
