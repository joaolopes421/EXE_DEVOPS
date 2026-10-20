terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

variable "db_password" {
  type    = string
  default = "senha_lab_123"
}

variable "grafana_password" {
  type    = string
  default = "grafana_lab_123"
}

resource "docker_network" "monitoring" {
  name = "monitoring-net"
}

resource "docker_volume" "db_data" { name = "db_data" }
resource "docker_volume" "prometheus_data" { name = "prometheus_data" }
resource "docker_volume" "grafana_data" { name = "grafana_data" }

resource "docker_image" "nginx" { name = "nginx:latest" }
resource "docker_image" "postgres" { name = "postgres:16" }
resource "docker_image" "cadvisor" { name = "gcr.io/cadvisor/cadvisor:latest" }
resource "docker_image" "prometheus" { name = "prom/prometheus:latest" }
resource "docker_image" "grafana" { name = "grafana/grafana:latest" }

resource "docker_container" "web" {
  name  = "web"
  image = docker_image.nginx.image_id
  ports {
    internal = 80
    external = 8080
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
  volumes {
    container_path = "/usr/share/nginx/html"
    host_path      = "${abspath(path.cwd)}/site"
    read_only      = true
  }
}

resource "docker_container" "db" {
  name  = "db"
  image = docker_image.postgres.image_id
  env = [
    "POSTGRES_USER=admin",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=devopsdb"
  ]
  ports {
    internal = 5432
    external = 5432
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
  volumes {
    container_path = "/var/lib/postgresql/data"
    volume_name    = docker_volume.db_data.name
  }
}

resource "docker_container" "cadvisor" {
  name       = "cadvisor"
  image      = docker_image.cadvisor.image_id
  privileged = true
  ports {
    internal = 8080
    external = 8081
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
  volumes {
    container_path = "/rootfs"
    host_path      = "/"
    read_only      = true
  }
  volumes {
    container_path = "/sys"
    host_path      = "/sys"
    read_only      = true
  }
  volumes {
    container_path = "/var/lib/docker"
    host_path      = "/var/lib/docker"
    read_only      = true
  }
  volumes {
    container_path = "/var/run"
    host_path      = "/var/run"
    read_only      = true
  }
}

resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = docker_image.prometheus.image_id
  ports {
    internal = 9090
    external = 9090
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
  volumes {
    container_path = "/etc/prometheus/prometheus.yml"
    host_path      = "${abspath(path.cwd)}/prometheus.yml"
    read_only      = true
  }
  volumes {
    container_path = "/prometheus"
    volume_name    = docker_volume.prometheus_data.name
  }
}

resource "docker_container" "grafana" {
  name  = "grafana"
  image = docker_image.grafana.image_id
  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_password}"
  ]
  ports {
    internal = 3000
    external = 3000
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
  volumes {
    container_path = "/var/lib/grafana"
    volume_name    = docker_volume.grafana_data.name
  }
}
