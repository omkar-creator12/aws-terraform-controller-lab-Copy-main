terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "Terraform-Controller-Lab"
      ManagedBy = "Terraform-Outer"
    }
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "tf-runner-key-outer-lab"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/tf-runner-key.pem"
  file_permission = "0400"
}

resource "aws_iam_role" "terraform_runner_role" {
  name = "terraform-controller-outer-lab-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.terraform_runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "runner_profile" {
  name = "terraform-controller-outer-lab-profile"
  role = aws_iam_role.terraform_runner_role.name
}

resource "aws_security_group" "runner_sg" {
  name        = "terraform-controller-outer-lab-sg"
  description = "SSH access to Terraform controller"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from current public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "terraform_runner" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.runner_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.runner_profile.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y curl wget gpg git unzip

    install -m 0755 -d /etc/apt/keyrings
    wget -qO- https://apt.releases.hashicorp.com/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
    chmod 0644 /etc/apt/keyrings/hashicorp.gpg

    echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
      > /etc/apt/sources.list.d/hashicorp.list

    apt-get update -y
    apt-get install -y terraform

    mkdir -p /home/ubuntu/secondary-infra
    cat > /home/ubuntu/secondary-infra/main.tf <<'INNER_TF'
    terraform {
      required_version = ">= 1.5.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.0"
        }
      }
    }

    variable "aws_region" {
      type    = string
      default = "us-east-1"
    }

    provider "aws" {
      region = var.aws_region
    }

    resource "random_id" "bucket_suffix" {
      byte_length = 4
    }

    resource "aws_s3_bucket" "test_bucket" {
      bucket        = "nested-tf-bucket-$${random_id.bucket_suffix.hex}"
      force_destroy = true

      tags = {
        CreatedBy   = "EC2-Terraform-Runner"
        Environment = "Nested-Lab"
      }
    }

    output "created_bucket_name" {
      value = aws_s3_bucket.test_bucket.bucket
    }
    INNER_TF

    chown -R ubuntu:ubuntu /home/ubuntu/secondary-infra
  EOF

  tags = {
    Name = "terraform-controller-outer-lab"
  }
}
