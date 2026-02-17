# A2A Multi-Agent with Memory Bank (adk-mb)

> **⚠️ DISCLAIMER**: THIS DEMO IS INTENDED FOR DEMONSTRATION PURPOSES ONLY. IT IS NOT INTENDED FOR USE IN A PRODUCTION ENVIRONMENT.
>
> **⚠️ Important**: A2A is a work in progress (WIP). In the near future there might be changes that are different from what is demonstrated here.
>
> **⚠️ Important**: Please run it in **Cloud Shell** to ensure you have the proper permissions.

This document describes a multi-agent setup using Agent2Agent (A2A), ADK (Agent Development Kit), Agent Engine, MCP (Model Context Protocol) servers, and **Vertex AI Memory Bank** for conversation persistence. The application demonstrates how the A2A protocol works between agents with memory capabilities.

## Overview

This web application demonstrates the integration of Google's open-source frameworks Agent2Agent (A2A) and Agent Development Kit (ADK) for multi-agent orchestration with Model Context Protocol (MCP) clients. The application features a host agent coordinating tasks between specialized remote A2A agents that interact with various MCP servers to fulfill user requests.

### Key Features

- **Multi-Agent Orchestration**: Host agent delegates tasks to specialized agents (Cocktail, Weather)
- **Memory Bank Integration**: Conversation history persisted using Vertex AI Memory Bank (the "mb" in "adk-mb")
- **MCP Protocol**: Agents communicate with remote MCP servers for data retrieval
- **A2A Protocol**: Standardized agent-to-agent communication
- **CI/CD Pipeline**: Automated deployment using GitHub Actions and Terraform

### Architecture

The application utilizes a multi-agent architecture where a host agent delegates tasks to remote A2A agents (Cocktail and Weather) based on the user's query. These agents then interact with corresponding remote MCP servers.

**Host Agent is built using A2A Server with Memory Bank integration.**

![architecture](asset/a2a_ae_diagram.png)

### Application Screenshot

![screenshot](asset/screenshot.png)

## Core Components

### Agents

The application employs three distinct agents with "adk-mb" naming:

- **Hosting Agent adk-mb - ADK**: The main orchestrator that receives user queries, determines required tasks, delegates to appropriate specialized agents, and maintains conversation memory
- **Cocktail Agent adk-mb - ADK**: Handles requests related to cocktail recipes and ingredients by interacting with the Cocktail MCP server
- **Weather Agent adk-mb - ADK**: Manages requests related to weather forecasts by interacting with the Weather MCP server

### MCP Servers and Tools

The agents interact with the following MCP servers:

1. **Cocktail MCP Server** (`cocktail-remote-mcp-server-adk-mb`)
   - Provides 5 tools:
     - `search cocktail by name`
     - `list all cocktail by first letter`
     - `search ingredient by name`
     - `list random cocktails`
     - `lookup full cocktail details by id`

2. **Weather MCP Server** (`weather-remote-mcp-server-adk-mb`)
   - Provides 3 tools:
     - `get weather forecast by city name`
     - `get weather forecast by coordinates`
     - `get weather alert by state code`

### Frontend

- **Gradio Web Interface** (`a2a-frontend-adk-mb`): User-facing chat interface deployed on Cloud Run

### Memory Bank

The "mb" in "adk-mb" stands for Memory Bank:
- Conversation sessions are automatically saved to Vertex AI Memory Bank
- Enables agents to recall previous conversations
- Semantic memory generation for improved context retention
- Accessed via `adk.tools.preload_memory` in agent tools

## Example Usage

Here are some example questions you can ask the chatbot:

- `What are the ingredients for a Margarita?`
- `List a random cocktail`
- `What's the weather in New York?`
- `What's the weather in San Francisco and what cocktail should I drink there?`

## Project Structure

```
.
├── asset/                          # Static assets
│   ├── a2a_ae_diagram.png
│   └── screenshot.png
├── deployment/                     # Deployment scripts and configs
│   ├── deploy_agents.py           # Agent deployment script
│   ├── notebooks/                 # Deployment notebooks
│   └── terraform/                 # Infrastructure as code
│       ├── main.tf
│       ├── cloudrun.tf
│       ├── variables.tf
│       └── backend.tf
├── logs/                          # Log files (gitignored)
├── scripts/                       # Utility scripts
│   ├── check_agent_exists.py
│   ├── cleanup_engines.py
│   ├── get_token.py
│   ├── inspect_fastmcp.py
│   └── debug/                    # Debug scripts
├── src/                          # Source code
│   ├── a2a_agents/               # Agent implementations
│   │   ├── cocktail_agent/
│   │   │   ├── agent_executor.py
│   │   │   └── cocktail_agent_card.py
│   │   ├── weather_agent/
│   │   │   ├── agent_executor.py
│   │   │   └── weather_agent_card.py
│   │   ├── hosting_agent/
│   │   │   ├── agent_executor.py
│   │   │   └── hosting_agent_card.py
│   │   └── common/
│   │       ├── adk_base_mcp_agent_executor.py
│   │       └── adk_orchestrator_agent.py
│   ├── frontend/                 # Gradio frontend
│   │   ├── main.py
│   │   ├── Dockerfile
│   │   └── pyproject.toml
│   └── mcp_servers/              # MCP server implementations
│       ├── cocktail_mcp_server/
│       └── weather_mcp_server/
├── tests/                        # Test files
│   ├── integration/              # Integration tests
│   ├── load_test/                # Load testing
│   └── unit/                     # Unit tests
├── .github/
│   └── workflows/
│       └── deploy.yml            # CI/CD pipeline
├── pyproject.toml
└── README.md
```

## Setup and Deployment

### Prerequisites

Before deploying, ensure you have:

1. [Python 3.12+](https://www.python.org/downloads/)
2. gcloud SDK: [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)
3. **(Optional) uv**: Python package management tool [https://docs.astral.sh/uv/getting-started/installation/](https://docs.astral.sh/uv/getting-started/installation/)
4. Google Cloud Project with:
   - Vertex AI API enabled
   - Cloud Run API enabled
   - Artifact Registry API enabled
   - Workload Identity Federation configured (for CI/CD)

### Manual Deployment

#### 1. Set Up Environment Variables

Create a `.env` file in the project root:

```bash
PROJECT_ID="your-project-id"
PROJECT_NUMBER="your-project-number"
GOOGLE_CLOUD_REGION="us-central1"
BUCKET_NAME="your-bucket-name"
CT_MCP_SERVER_URL="https://cocktail-remote-mcp-server-adk-mb-{PROJECT_NUMBER}.{REGION}.run.app/mcp/sse"
WEA_MCP_SERVER_URL="https://weather-remote-mcp-server-adk-mb-{PROJECT_NUMBER}.{REGION}.run.app/mcp/sse"
GOOGLE_GENAI_MODEL="gemini-2.5-flash"
```

#### 2. Deploy MCP Servers

Navigate to each MCP server directory and deploy to Cloud Run:

```bash
# Deploy Cocktail MCP Server
cd src/mcp_servers/cocktail_mcp_server
gcloud builds submit --tag gcr.io/$PROJECT_ID/cocktail-remote-mcp-server-adk-mb
gcloud run deploy cocktail-remote-mcp-server-adk-mb \
  --image gcr.io/$PROJECT_ID/cocktail-remote-mcp-server-adk-mb \
  --region us-central1 \
  --platform managed

# Deploy Weather MCP Server
cd ../weather_mcp_server
gcloud builds submit --tag gcr.io/$PROJECT_ID/weather-remote-mcp-server-adk-mb
gcloud run deploy weather-remote-mcp-server-adk-mb \
  --image gcr.io/$PROJECT_ID/weather-remote-mcp-server-adk-mb \
  --region us-central1 \
  --platform managed
```

#### 3. Deploy A2A Agents

Install dependencies and deploy agents to Vertex AI Agent Engine:

```bash
# Install dependencies
pip install -e .

# Deploy agents (cocktail, weather, and hosting)
python deployment/deploy_agents.py
```

The deployment script will:
- Deploy Cocktail Agent adk-mb - ADK
- Deploy Weather Agent adk-mb - ADK
- Deploy Hosting Agent adk-mb - ADK
- Configure Memory Bank integration
- Set up agent-to-agent communication

#### 4. Deploy Frontend

Deploy the Gradio frontend to Cloud Run:

```bash
cd src/frontend
gcloud run deploy a2a-frontend-adk-mb \
  --source . \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars "PROJECT_ID=$PROJECT_ID,PROJECT_NUMBER=$PROJECT_NUMBER,AGENT_ENGINE_ID=<hosting-agent-id>,GOOGLE_CLOUD_LOCATION=us-central1"
```

#### 5. Configure IAM Permissions

Grant the compute service account permission to invoke MCP servers:

```bash
gcloud run services add-iam-policy-binding cocktail-remote-mcp-server-adk-mb \
  --region us-central1 \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding weather-remote-mcp-server-adk-mb \
  --region us-central1 \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/run.invoker"
```

### CI/CD Deployment (Recommended)

The project includes automated deployment via GitHub Actions:

1. **Setup Workload Identity Federation** (see `github-actions-wif-auth.md`)

2. **Configure Secrets**:
   - Set up GitHub environments: `staging` and `production`
   - Configure environment variables in `.github/workflows/deploy.yml`

3. **Trigger Deployment**:
   - Push to `staging` branch for staging deployment
   - Push to `main` branch for production deployment

The CI/CD pipeline automatically:
- Detects which components have changed
- Builds and deploys MCP servers to Cloud Run
- Deploys agents to Vertex AI Agent Engine
- Deploys frontend to Cloud Run
- Applies Terraform infrastructure changes
- Skips deployment of unchanged components

## Testing

### Run Integration Tests

```bash
# Test MCP servers
python tests/integration/manual_test_mcp_servers.py

# Test cocktail agent locally
python tests/integration/test_cocktail_agent_local.py

# Test hosting agent remotely
python tests/integration/test_hosting_agent_remote.py

# Test deployed frontend
python tests/integration/test_frontend_deployed.py
```

### Run Load Tests

```bash
cd tests/load_test
python load_test.py
```

## Monitoring and Debugging

### View Logs

**Cloud Run Services:**
```bash
gcloud run services logs read cocktail-remote-mcp-server-adk-mb --region us-central1
gcloud run services logs read weather-remote-mcp-server-adk-mb --region us-central1
gcloud run services logs read a2a-frontend-adk-mb --region us-central1
```

**Agent Engines:**
- View in Cloud Console: Vertex AI > Agent Builder > Agents

### Debug Scripts

Utility scripts are available in `scripts/` and `scripts/debug/`:
- `check_agent_exists.py`: Check if hosting agent is deployed
- `cleanup_engines.py`: Clean up old agent engines
- `get_token.py`: Get authentication token
- `list_workflows.sh`: List GitHub workflows
- `get_github_run_log.sh`: Fetch GitHub Actions logs

## Naming Convention: "adk-mb"

All components use the "adk-mb" suffix:
- **adk**: Agent Development Kit
- **mb**: Memory Bank (Vertex AI Memory Bank integration)

This distinguishes this implementation from other ADK projects and clearly indicates the memory persistence feature.

## Memory Bank Feature

The Memory Bank integration enables:
- **Session Persistence**: Conversations are saved after agent completion
- **Semantic Memory**: Automatic generation of semantic memories
- **Context Retrieval**: Agents can access previous conversation context
- **User-Specific Memory**: Memories are scoped by user ID

Memory is automatically saved via the `auto_save_session_to_memory_callback` in the agent executors.

## Troubleshooting

### Common Issues

1. **Agent Not Found**: Ensure agents are deployed with correct display names (`Hosting Agent adk-mb - ADK`)
2. **MCP Server 403/404**: Verify IAM permissions for compute service account
3. **Frontend Connection Error**: Check `AGENT_ENGINE_ID` environment variable
4. **Memory Not Persisting**: Verify Memory Bank service initialization in agent executor

### Support

For issues and questions:
- Check deployment logs: `logs/final_deployment.log`
- Review CI/CD pipeline logs in GitHub Actions
- Consult documentation in `deployment/` and `docs/` folders

## Documentation

Additional documentation:
- `FRONTEND_DEPLOYMENT_SUMMARY.md`: Frontend deployment details
- `REORGANIZATION_SUMMARY.md`: Code organization and naming updates
- `github-actions-wif-auth.md`: GitHub Actions Workload Identity setup

## Disclaimer

**Important**: The sample code provided is for demonstration purposes and illustrates the mechanics of the Agent-to-Agent (A2A) protocol. When building production applications, it is critical to treat any agent operating outside of your direct control as a potentially untrusted entity.

All data received from an external agent—including but not limited to its AgentCard, messages, artifacts, and task statuses—should be handled as untrusted input. For example, a malicious agent could provide an AgentCard containing crafted data in its fields (e.g., description, name, skills.description). If this data is used without sanitization to construct prompts for a Large Language Model (LLM), it could expose your application to prompt injection attacks. Failure to properly validate and sanitize this data before use can introduce security vulnerabilities into your application.

Developers are responsible for implementing appropriate security measures, such as input validation and secure handling of credentials to protect their systems and users.

## License

This project is licensed under the [License](LICENSE).
