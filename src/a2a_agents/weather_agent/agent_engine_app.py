"""Agent Engine entrypoint for Weather Agent.

This module is referenced by source-based Agent Engine deployment.
The `agent_engine` object is the entrypoint that Agent Engine serves.
"""

from vertexai.preview.reasoning_engines import A2aAgent

from a2a_agents.weather_agent.agent_executor import WeatherAgentExecutor
from a2a_agents.weather_agent.weather_agent_card import weather_agent_card

agent_engine = A2aAgent(
    agent_card=weather_agent_card,
    agent_executor_builder=WeatherAgentExecutor,
)
