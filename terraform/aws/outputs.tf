output "frontend_url" {
  description = "URL of the Angular frontend on the app server."
  value       = "http://${aws_eip.app.public_ip}"
}

output "backend_api_url" {
  description = "Base URL of the backend REST API."
  value       = "http://${aws_eip.app.public_ip}:8080"
}

output "swagger_ui_url" {
  description = "Swagger UI of the backend API."
  value       = "http://${aws_eip.app.public_ip}:8080/swagger"
}

output "app_public_ip" {
  description = "Public IP of the app server (for SSH)."
  value       = aws_eip.app.public_ip
}

output "database_endpoint" {
  description = "Hostname of the RDS PostgreSQL instance (VPC-internal)."
  value       = aws_db_instance.this.address
}
