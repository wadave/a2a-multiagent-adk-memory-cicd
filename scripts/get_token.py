from google.oauth2 import id_token
from google.auth.transport.requests import Request
import os
import sys

# Target URL for the ID token. Should be the base URL of the service.
url = os.environ.get("TARGET_SERVICE_URL")

if not url:
    print("ERROR: TARGET_SERVICE_URL environment variable is not set.")
    print("Example: export TARGET_SERVICE_URL=https://your-service-url.run.app")
    sys.exit(1)

try:
    auth_req = Request()
    token = id_token.fetch_id_token(auth_req, url)
    print(f"curl -v -N -H \"Authorization: Bearer {token}\" -H \"Accept: text/event-stream\" {url}/mcp/sse")
except Exception as e:
    print(f"Failed to fetch token: {e}")
