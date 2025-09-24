terraform {
  required_version = ">= 1.6.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }

  # keep your MinIO backend for OSS demos
  # backend "s3" {
#     bucket                      = "tfstate"
#     key                         = "project_oss/terraform.tfstate"
#    region                      = "us-east-1"
#    endpoints                   = { s3 = "http://localhost:9000" }
#    access_key                  = "minio"
#    secret_key                  = "minio12345"
#    skip_credentials_validation = true
#   skip_requesting_account_id  = true
#    skip_metadata_api_check     = true
#    use_path_style              = true
#  }
}

########################################
# Providers
########################################

# Docker (unchanged)
provider "docker" {}

# AWS — reads credentials from your shell env:
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN (if using STS),
#   and AWS_REGION (or set var.aws_region below).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project      = "project_oss"
      Purpose      = "cost-demo"
      Application  = "terraform-chronicles"
      Environment  = "dev"
      Team         = "platform"
      Owner        = "you@example.com"
      CostCenter   = "ENG-1234"
    }
  }  

}

########################################
# Variables (simple toggles for safety)
########################################

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Flip to false if you want to disable AWS creation for a run.
variable "enable_aws" {
  type    = bool
  default = true
}

variable "instance_type" {
  type    = string
  default = "t3.micro" # cheap demo size
}

########################################
# AWS: small, priceable demo resources
########################################

# Random suffix so the S3 bucket is globally unique
resource "random_id" "suffix" {
  byte_length = 3
  count       = var.enable_aws ? 1 : 0
}

# S3 bucket (often shows up in cost estimation)
resource "aws_s3_bucket" "cost_demo" {
  count  = var.enable_aws ? 1 : 0
  bucket = "oss-cost-demo-${random_id.suffix[0].hex}"
  force_destroy = true

  tags = {
    Name = "oss-cost-demo-${random_id.suffix[0].hex}"
  }
}

# Grab a recent Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  count       = var.enable_aws ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# EC2 instance in the default VPC (works if your account still has the default)
resource "aws_instance" "cost_demo" {
  count         = var.enable_aws ? 1 : 0
  ami           = data.aws_ami.al2023[0].id
  instance_type = var.instance_type

  # modest disk so the EBS shows up in cost calcs too
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "oss-cost-demo"
  }
}

variable "enable_aws_spot" {
  type    = bool
  default = true
}

variable "spot_instance_type" {
  type    = string
  default = "t3.micro"
}

resource "aws_instance" "cost_demo_spot" {
  count         = var.enable_aws && var.enable_aws_spot ? 1 : 0
  ami           = data.aws_ami.al2023[0].id
  instance_type = var.spot_instance_type

  instance_market_options {
    market_type = "spot"
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "oss-cost-demo-spot"
  }
}


########################################
# Docker (your existing demo)
########################################

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

resource "docker_image" "alpine_latest" {
  name         = "alpine:latest"   # anti-pattern: floating tag
  keep_locally = true
}

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

  # 🚩 Escalated Linux capabilities
  capabilities {
    add = ["NET_ADMIN", "SYS_ADMIN"]
  }

  # 🚩 Bind-mount the Docker socket (container can control the host’s Docker)
  mounts {
    target    = "/var/run/docker.sock"
    source    = "/var/run/docker.sock"
    type      = "bind"
    read_only = false
  }

  command = ["sh", "-c", "sleep 3600"]
}
