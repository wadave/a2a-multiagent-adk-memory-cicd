import os
import logging
import time
import vertexai
from google.genai import types
from dotenv import load_dotenv

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def cleanup_reasoning_engines():
    """
    Cleans up duplicate or unnamed Reasoning Engines in Vertex AI.
    Uses a conservative 30-second delay between deletions to avoid 
    'Reasoning Engine Write Requests' quota limits (typically 10 RPM).
    """
    load_dotenv()
    
    project_id = os.environ.get("PROJECT_ID")
    location = os.environ.get("LOCATION", "us-central1")
    
    if not project_id:
        logging.error("PROJECT_ID environment variable is not set.")
        return

    logging.info(f"Initializing Vertex AI Client for project: {project_id}, location: {location}")
    
    vertexai.init(project=project_id, location=location)
    client = vertexai.Client(
        project=project_id,
        location=location,
        http_options=types.HttpOptions(
            api_version="v1beta1", 
            base_url=f"https://{location}-aiplatform.googleapis.com/"
        ),
    )
    
    # Engines with these names are likely leaks from previous debug/local runs
    TARGET_DISPLAY_NAMES = {
        "Hosting Agent Engine",
        "weather_agent Engine",
        "Cocktail Agent Engine",
        "Adk Base Mcp Agent Engine",
        "Adk Orchestrator Agent Engine",
        "—",
        ""
    }

    try:
        logging.info("Fetching list of all Reasoning Engines...")
        engines = list(client.agent_engines.list())
        logging.info(f"Found {len(engines)} total engine instances.")
        
        deleted_count = 0
        for engine in engines:
            api_res = engine.api_resource
            display_name = getattr(api_res, 'display_name', '') or getattr(api_res, 'displayName', '')
            engine_resource_id = getattr(api_res, 'name', 'Unknown')
            
            should_delete = False
            
            # 1. Unnamed or placeholder engines
            if not display_name or display_name.strip() in ("", "—"):
                should_delete = True
            
            # 2. Engines matching our known leak patterns
            if display_name in TARGET_DISPLAY_NAMES:
                should_delete = True
                
            # 3. Engines containing legacy naming patterns 
            if "Engine" in display_name and "ADK Agent" not in display_name:
                should_delete = True
            
            if "cocktail_agent" in display_name:
                should_delete = True

            if should_delete:
                logging.info(f"Triggering deletion for: '{display_name}' [{engine_resource_id}]")
                try:
                    client.agent_engines.delete(name=engine_resource_id)
                    deleted_count += 1
                    
                    # QUOTA SAFETY: Wait 15 seconds to stay well under 10 RPM
                    logging.info("Quota safety wait: 15s...")
                    time.sleep(15)
                    
                except Exception as delete_err:
                    if "429" in str(delete_err):
                        logging.warning("Quota hit (429). Cooling down for 60s...")
                        time.sleep(60)
                    else:
                        logging.error(f"Error deleting {engine_resource_id}: {delete_err}")
            else:
                logging.info(f"Keeping active engine: '{display_name}'")
                
        logging.info(f"Cleanup cycle complete. Initiated {deleted_count} deletions.")
        
    except Exception as list_err:
        logging.error(f"Failed to list or process engines: {list_err}")

if __name__ == "__main__":
    cleanup_reasoning_engines()
