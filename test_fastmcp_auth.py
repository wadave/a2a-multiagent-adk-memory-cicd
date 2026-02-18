import asyncio
from fastmcp.client import Client
from tests import test_config
from tests.integration.test_cocktail_mcp_server import get_auth_token, BearerAuth

async def main():
    url = test_config.CT_MCP_SERVER_URL + "/mcp/sse"
    print(f"URL: {url}")
    token = get_auth_token(url)
    print(f"Token present: {bool(token)}")
    auth = BearerAuth(token) if token else None
    
    try:
        async with Client(url, auth=auth) as client:
            tools = await client.list_tools()
            print("Tools:", [t.name for t in tools])
    except Exception as e:
        print(f"Failed: {type(e).__name__} - {e}")

if __name__ == "__main__":
    asyncio.run(main())
