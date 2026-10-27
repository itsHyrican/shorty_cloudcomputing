# Shared Docker network for all Shorty containers.

resource "docker_network" "this" {
  name   = "${var.project_name}-net"
  driver = "bridge"
}
