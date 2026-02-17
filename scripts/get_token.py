from google.oauth2 import id_token
from google.auth.transport.requests import Request
import os

url = "https://cocktail-remote-mcp-server-496235138247.us-central1.run.app"
try:
    auth_req = Request()
    token = id_token.fetch_id_token(auth_req, url)
    print(f"curl -v -N -H \"Authorization: Bearer {token}\" -H \"Accept: text/event-stream\" {url}/mcp/sse")
except Exception as e:
    print(f"Failed to fetch token: {e}")
