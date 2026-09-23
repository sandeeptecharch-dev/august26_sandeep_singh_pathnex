terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# Latest Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group
resource "aws_security_group" "jenkins_sg" {
  name   = "jenkins-sg2"
  vpc_id = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2
resource "aws_instance" "jenkins_server" {

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "c7i-flex.large"
  key_name = "pathnex-key"

  vpc_security_group_ids = [
    aws_security_group.jenkins_sg.id
  ]

  user_data = <<-EOF
    #!/bin/bash

    dnf update -y

    # Install Java
    dnf install java-21-amazon-corretto -y

    # Jenkins repository
    wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/rpm-stable/jenkins.repo

    rpm --import \
    https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key

    # Install Jenkins
    dnf install jenkins -y

    # Enable Jenkins
    systemctl enable jenkins

    # Start Jenkins
    systemctl start jenkins
  EOF

  tags = {
    Name = "Jenkins-Server"
  }
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins_server.public_ip}:8080"
}
