output "frontend_url" {
  description = "URL of the Angular frontend."
  value       = "http://localhost:${var.frontend_host_port}"
}

output "backend_api_url" {
  description = "Base URL of the backend REST API."
  value       = "http://localhost:${var.backend_host_port}"
}

output "swagger_ui_url" {
  description = "Swagger UI of the backend API."
  value       = "http://localhost:${var.backend_host_port}/swagger"
}

output "database" {
  description = "Local database connection details."
  value = {
    host = "localhost"
    port = var.db_host_port
    name = var.db_name
    user = var.db_user
  }
}
