# Frontend (Angular SSR) – image built from the repository.

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
