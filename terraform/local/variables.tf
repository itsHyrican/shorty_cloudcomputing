variable "project_name" {
  description = "Prefix for container, network and volume names."
  type        = string
  default     = "shorty"
}

variable "docker_host" {
  description = "Docker daemon endpoint. Empty = provider default. On Windows (Docker Desktop) use \"npipe:////./pipe/docker_engine\"."
  type        = string
  default     = ""
}

variable "postgres_image" {
  description = "PostgreSQL image used for the database container."
  type        = string
  default     = "postgres:16-alpine"
}

variable "backend_image_tag" {
  description = "Tag for the backend image built from the repository (e.g. \"latest\" or a version such as \"1.0\")."
  type        = string
  default     = "latest"
}

variable "frontend_image_tag" {
  description = "Tag for the frontend image built from the repository (e.g. \"latest\" or a version such as \"1.0\")."
  type        = string
  default     = "latest"
}

variable "db_name" {
  description = "Name of the PostgreSQL database."
  type        = string
  default     = "shorty"
}

variable "db_user" {
  description = "PostgreSQL superuser created in the container."
  type        = string
  default     = "shorty"
}

variable "db_password" {
  description = "Password for the PostgreSQL user."
  type        = string
  sensitive   = true
  default     = "shorty"
}

variable "db_host_port" {
  description = "Host port the database is published on."
  type        = number
  default     = 5432
}

variable "backend_host_port" {
  description = "Host port the backend API is published on."
  type        = number
  default     = 8080
}

variable "frontend_host_port" {
  description = "Host port the frontend is published on."
  type        = number
  default     = 4200
}

variable "default_ttl_hours" {
  description = "Default lifetime of a short link in hours (backend ShortUrlOptions)."
  type        = number
  default     = 24
}

variable "max_ttl_hours" {
  description = "Maximum lifetime of a short link in hours (backend ShortUrlOptions)."
  type        = number
  default     = 720
}

variable "cleanup_interval_minutes" {
  description = "How often the backend sweeps expired links (minutes)."
  type        = number
  default     = 15
}

variable "frontend_allowed_hosts" {
  description = "Comma-separated hostnames the Angular SSR server accepts in the Host header (SSRF protection). Must cover the address(es) users open in the browser."
  type        = string
  default     = "localhost,127.0.0.1"
}
