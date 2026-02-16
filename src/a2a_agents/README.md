# A2A Multi-Agent System

## Overview

This project implements a multi-agent system using the A2A (Agent-to-Agent) protocol and Google's Vertex AI. The system consists of an orchestrator agent and several specialized agents that work together to handle user requests.

The architecture follows a hierarchical pattern where a `HostingAgent` acts as the main entry point, delegating tasks to the appropriate specialized agents through an `OrchestratorAgent`.

## Project Structure

```
/
├── cocktail_agent/         # Specialized agent for cocktail recipes
│   ├── cocktail_agent_card.py
│   └── agent_executor.py
├── common/                 # Common modules and base classes
│   ├── adk_base_mcp_agent_executor.py
│   ├── adk_orchestrator_agent_executor.py
│   ├── adk_orchestrator_agent.py
│   ├── agent_configs.py
│   ├── auth_utils.py
│   └── remote_connection.py
├── hosting_agent/          # Main entry point and orchestrator
│   ├── agent_executor.py
│   └── hosting_agent_card.py
├── weather_agent/          # Specialized agent for weather forecasts
│   ├── weather_agent_card.py
│   └── agent_executor.py
└── README.md               # This file
```

## Agents

### Orchestrator Agent

The `OrchestratorAgent` is the core of the multi-agent system. It is responsible for:

-   **Agent Discovery:** Discovering available agents and their capabilities by retrieving their agent cards.
-   **Task Delegation:** Receiving user requests and delegating them to the most appropriate specialized agent.
-   **Session Management:** Managing the conversation and context across multiple turns.

### Hosting Agent

The `HostingAgent` is the main entry point for user requests. It wraps the `OrchestratorAgent` and provides a unified interface to the multi-agent system. It is responsible for initializing the orchestrator with the addresses of the remote agents.

### Cocktail Agent

The `CocktailAgent` is a specialized agent that provides information about cocktails. It can answer questions about cocktail recipes and ingredients.

### Weather Agent

The `WeatherAgent` is a specialized agent that provides weather forecasts. It can retrieve the weather for a given city or state.

## Getting Started

1.  **Install dependencies:**

    ```bash
    uv sync
    ```

2.  **Set up environment variables:**

    Create a `.env` file by copying the `.env.example` file and populate it with the necessary credentials and agent URLs.

3.  **Run the agents:**

    Each agent can be run as a separate service. The specific commands to run each agent will depend on the deployment environment.

## Deployment

The agents are deployed via `deployment/deploy_agents.py` which deploys all three agents to Google's Agent Engine with memory bank configuration.
