terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      # Community-maintained successor of the former hashicorp/docker provider.
      source  = "kreuzwerker/docker"
      version = "~> 4.6"
    }
  }
}

provider "docker" {
  # Defaults to the local Docker daemon. On Windows (Docker Desktop) set
  # docker_host in terraform.tfvars, e.g. "npipe:////./pipe/docker_engine".
  host = var.docker_host != "" ? var.docker_host : null
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

resource "docker_network" "this" {
  name   = "${var.project_name}-net"
  driver = "bridge"
}

# ---------------------------------------------------------------------------
# PostgreSQL
# ---------------------------------------------------------------------------

resource "docker_container" "db" {
  name  = "${var.project_name}-db"
  image = var.postgres_image

  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
  ]

  ports {
    internal = 5432
    external = var.db_host_port
    protocol = "tcp"
  }

  # The named volume is created automatically and survives `terraform destroy`,
  # so the database keeps its data. Remove it manually with
  # `docker volume rm ${var.project_name}-db-data` for a clean slate.
  volumes {
    volume_name    = "${var.project_name}-db-data"
    container_path = "/var/lib/postgresql/data"
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U ${var.db_user} -d ${var.db_name}"]
    interval = "5s"
    timeout  = "5s"
    retries  = 10
  }

  networks_advanced {
    name = docker_network.this.name
  }

  restart = "on-failure"
}

# ---------------------------------------------------------------------------
# Backend (.NET) – image built from the repository
# ---------------------------------------------------------------------------

resource "docker_image" "backend" {
  name         = "${var.project_name}-backend:${var.backend_image_tag}"
  keep_locally = true

  build {
    context    = "../../shorty_backend"
    dockerfile = "shorty_backend/Dockerfile"
  }
}

resource "docker_container" "backend" {
  name  = "${var.project_name}-backend"
  image = docker_image.backend.name

  env = [
    "ASPNETCORE_URLS=http://+:8080",
    # Inside the Docker network the database is reachable by container name.
    "ConnectionStrings__DefaultConnection=Host=${docker_container.db.name};Port=5432;Database=${var.db_name};Username=${var.db_user};Password=${var.db_password}",
    "ShortUrlOptions__DefaultTtlHours=${var.default_ttl_hours}",
    "ShortUrlOptions__MaxTtlHours=${var.max_ttl_hours}",
    "ShortUrlOptions__CleanupIntervalMinutes=${var.cleanup_interval_minutes}",
  ]

  ports {
    internal = 8080
    external = var.backend_host_port
    protocol = "tcp"
  }

  networks_advanced {
    name = docker_network.this.name
  }

  # The backend applies EF migrations on startup and retries while the
  # database is still coming up, so this only needs an ordering hint.
  depends_on = [docker_container.db]
  restart    = "on-failure"
}

# ---------------------------------------------------------------------------
# Frontend (Angular SSR) – image built from the repository
# ---------------------------------------------------------------------------

resource "docker_image" "frontend" {
  name         = "${var.project_name}-frontend:${var.frontend_image_tag}"
  keep_locally = true

  build {
    context    = "../../shorty_frontend"
    dockerfile = "Dockerfile"
    build_args = {
      # The browser (not the container) calls the API, so this must be the
      # address the user opens in their browser.
      API_URL = "http://localhost:${var.backend_host_port}"
    }
  }
}

resource "docker_container" "frontend" {
  name  = "${var.project_name}-frontend"
  image = docker_image.frontend.name

  env = [
    "PORT=4000",
    # Angular 22 SSR validates the Host header against an allow list (SSRF
    # protection) and answers 400 for anything else, so the address users
    # open in their browser must be listed here.
    "NG_ALLOWED_HOSTS=${var.frontend_allowed_hosts}",
  ]

  ports {
    internal = 4000
    external = var.frontend_host_port
    protocol = "tcp"
  }

  networks_advanced {
    name = docker_network.this.name
  }

  restart = "on-failure"
}
