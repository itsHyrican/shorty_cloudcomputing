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
