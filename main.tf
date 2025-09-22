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

resource "docker_container" "nginx" {
  name  = "hcp-nginx" # different from your OSS demo
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }
}

resource "docker_container" "nginx_extra" {
  name  = "hcp-nginx-extra"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8081
  }
}
