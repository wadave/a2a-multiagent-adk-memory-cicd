import vertexai
from dotenv import load_dotenv
from google.genai import types

from tests import test_config

load_dotenv()

project_id = test_config.PROJECT_ID
location = test_config.LOCATION

# Agent IDs from deployment output
COCKTAIL_AGENT_ID = test_config.COCKTAIL_AGENT_ID
WEATHER_AGENT_ID = test_config.WEATHER_AGENT_ID

vertexai.init(project=project_id, location=location)

client = vertexai.Client(
    project=project_id,
    location=location,
    http_options=types.HttpOptions(
        api_version="v1beta1", base_url=f"https://{location}-aiplatform.googleapis.com/"
    ),
)


def test_remote_agent(agent_id, agent_name, query):
    print(f"\n--- Testing {agent_name} ({agent_id}) ---")
    try:
        agent = client.agent_engines.get(agent_id)
        print(f"Querying: {query}")
        # Reasoning Engine query method
        response = agent.query(input=query)
        print("Response received.")

        # Pretty print response
        if isinstance(response, dict):
            import json

            print(json.dumps(response, indent=2))
        else:
            print(response)

    except Exception as e:
        print(f"Error testing {agent_name}: {e}")
        import traceback

        traceback.print_exc()


def main():
    test_remote_agent(COCKTAIL_AGENT_ID, "Cocktail Agent", "What is in a margarita?")
    test_remote_agent(
        WEATHER_AGENT_ID, "Weather Agent", "What is the weather in New York, NY?"
    )


if __name__ == "__main__":
    main()
