terraform {
  backend "s3" {
    bucket       = "pathnex-bucket-sept26"
    key          = "pathnex/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


# -------------------------
# Variables
# -------------------------

variable "aws_region" {
  type        = string
  description = "Region where EC2 will be created"
  default     = "ap-south-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for names/tags"
  default     = "Pathnex-sep-2026"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default = {
    Project = "terraform-ec2"
  }
}

variable "key_name" {
  type        = string
  description = "EC2 SSH key pair name"
  default     = "pathnex-key"
}

provider "aws" {
  region = "ap-south-1"
}

# -------------------------
# S3 Bucket
# -------------------------

#resource "aws_s3_bucket" "pathnex_bucket" {
#  bucket = "pathnex-bucket-sep"
#
#  tags = {
#    Name = "Pathnex-S3"
#  }
#}


# Use default VPC (simple)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "web_sg" {
  name        = "pathnex-sep-tf-sg"
  description = "Allow HTTP only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    # For learning/testing.
    # Better: replace with YOUR_PUBLIC_IP/32
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "terraform-ec2"
    Name    = "pathnex-sep-tf-sg"
  }
}

resource "aws_instance" "sep-tf" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  # Attach EC2 Key Pair
  key_name = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "<h1>Hello All, Today is 18 sep 2026 and ec2 creation with the help of terraform is successful </h1>" > /var/www/html/index.html
              EOF

  tags = {
    Project = "terraform-for-ec2"
    Name    = "pathnex-sep-tf-instance"
    batch   = var.name_prefix
  }
}

output "instance_id" {
  value = aws_instance.sep-tf.id
}

output "public_ip" {
  value = aws_instance.sep-tf.public_ip
}

output "web_url" {
  value = "http://${aws_instance.sep-tf.public_ip}"
}