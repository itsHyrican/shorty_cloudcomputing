# Backend (.NET) – image built from the repository.

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
