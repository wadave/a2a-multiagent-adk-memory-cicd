"""Dummy Agent Engine app for initial Terraform deployment.

This placeholder is replaced by CI/CD pipelines after initial creation.
"""

from google.adk.agents import Agent
from vertexai.agent_engines import AdkApp

agent = Agent(
    model="gemini-2.0-flash",
    name="dummy_agent",
    instruction="You are a placeholder agent. Respond with: 'This is a placeholder agent deployed via Terraform. Please deploy the real agent via CI/CD.'",
)

agent_engine = AdkApp(agent=agent)
