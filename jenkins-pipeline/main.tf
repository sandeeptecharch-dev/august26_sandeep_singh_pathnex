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

# -----------------------------------
# Get Default VPC
# -----------------------------------

data "aws_vpc" "default" {
  default = true
}

# -----------------------------------
# Get subnets
# -----------------------------------

data "aws_subnets" "default" {

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -----------------------------------
# Latest Amazon Linux 2023
# -----------------------------------

data "aws_ami" "amazon_linux" {

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# -----------------------------------
# Security Group
# -----------------------------------

resource "aws_security_group" "app_sg" {

  name_prefix = "pathnex-app-"

  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "HTTP"

    from_port = 80
    to_port   = 80

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------
# Application EC2
# -----------------------------------

resource "aws_instance" "app_server" {

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id = data.aws_subnets.default.ids[0]
  key_name = "pathnex-key"
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash

              dnf update -y

              dnf install nginx -y

              systemctl enable nginx
              systemctl start nginx

              cat > /usr/share/nginx/html/index.html <<HTML
              <html>
              <body>

              <h1>Welcome to Pathnex</h1>

              <h2>Application deployed successfully!</h2>

              <p>Jenkins -> Terraform -> AWS EC2</p>

              </body>
              </html>
              HTML
              EOF

  tags = {
    Name = "Pathnex-App-Server"
  }
}

# -----------------------------------
# Output
# -----------------------------------

output "application_url" {

  value = "http://${aws_instance.app_server.public_ip}"

}
