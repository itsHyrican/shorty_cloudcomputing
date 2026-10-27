# PostgreSQL database container.

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
