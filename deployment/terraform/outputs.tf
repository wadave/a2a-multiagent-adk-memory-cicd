# Output the URLs for downstream consumption by CI/CD

output "cocktail_mcp_server_url" {
  description = "URL of the Cocktail MCP Server"
  value       = "${google_cloud_run_v2_service.cocktail_mcp_server.uri}/mcp/sse"
}

output "weather_mcp_server_url" {
  description = "URL of the Weather MCP Server"
  value       = "${google_cloud_run_v2_service.weather_mcp_server.uri}/mcp/sse"
}

output "frontend_url" {
  description = "URL of the A2A Frontend"
  value       = google_cloud_run_v2_service.a2a_frontend.uri
}

output "cocktail_mcp_server_name" {
  description = "Resource name of the Cocktail MCP Server"
  value       = google_cloud_run_v2_service.cocktail_mcp_server.name
}

output "weather_mcp_server_name" {
  description = "Resource name of the Weather MCP Server"
  value       = google_cloud_run_v2_service.weather_mcp_server.name
}

output "frontend_name" {
  description = "Resource name of the A2A Frontend"
  value       = google_cloud_run_v2_service.a2a_frontend.name
}
