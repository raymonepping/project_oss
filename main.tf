terraform {
  required_version = ">= 1.6.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

resource "docker_image" "alpine_latest" {
  name         = "alpine:latest"   # anti-pattern: floating tag
  keep_locally = true
}

# use OSS names to avoid clashing with the HCP-created containers
resource "docker_container" "nginx" {
  name  = "oss-nginx"
  image = docker_image.nginx.image_id
  ports {
    internal = 80
    external = 8080
  }
}

resource "docker_container" "nginx_extra" {
  name  = "oss-nginx-extra"
  image = docker_image.nginx.image_id
  ports {
    internal = 80
    external = 8081
  }
}

resource "docker_container" "risky" {
  name         = "oss-riskless" 
  image        = docker_image.alpine_latest.image_id

  # 🚩 Host networking removes isolation
  network_mode = "host"

  # 🚩 Full privileges defeat containment
  # privileged   = true

  # 🚩 Escalated Linux capabilities
  capabilities {
    add = ["NET_ADMIN", "SYS_ADMIN"]
  }

  # 🚩 Bind-mount the Docker socket (container can control the host’s Docker)
  mounts {
    target = "/var/run/docker.sock"
    source = "/var/run/docker.sock"
    type   = "bind"
    read_only = false
  }

  # Run and stay alive
  command = ["sh", "-c", "sleep 3600"]
}