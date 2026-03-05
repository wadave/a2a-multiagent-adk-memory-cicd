"""Agent Engine entrypoint for Cocktail Agent.

This module is referenced by source-based Agent Engine deployment.
The `agent_engine` object is the entrypoint that Agent Engine serves.
"""

from vertexai.preview.reasoning_engines import A2aAgent

from a2a_agents.cocktail_agent.agent_executor import CocktailAgentExecutor
from a2a_agents.cocktail_agent.cocktail_agent_card import cocktail_agent_card

agent_engine = A2aAgent(
    agent_card=cocktail_agent_card,
    agent_executor_builder=CocktailAgentExecutor,
)
