import vertexai
import sys

def check_agents():
    project_id = "${{ env.PROJECT_ID }}"
    region = "${{ env.REGION }}"
    # Local fallback for direct testing
    if project_id.startswith("$"): project_id = "dw-genai-dev"
    if region.startswith("$"): region = "us-central1"

    vertexai.init(project=project_id, location=region)
    client = vertexai.Client(project=project_id, location=region)
    
    for ae in client.agent_engines.list():
        dn = getattr(ae.api_resource, 'displayName', '') or getattr(ae.api_resource, 'display_name', '')
        if dn == "Hosting Agent adk-mb - ADK":
            print(ae.api_resource.name)
            sys.exit(0)
    print("")

if __name__ == "__main__":
    check_agents()
