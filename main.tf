provider "aws" {
  region = "us-east-2"
}

# ========== VPC with one public, and one private subnet

resource "aws_vpc" "terraform_example" {
  cidr_block = var.vpc_address_space
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.terraform_example.id
  cidr_block        = var.public_subnet_address_space
  availability_zone = var.public_az

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.terraform_example.id
  cidr_block        = var.private_subnet_address_space
  availability_zone = var.private_az

  tags = {
    Name = "Private Subnet"
  }
}

# ========== NAT Gateway, and required routes for private instances to talk to internet

resource "aws_eip" "nat_gateway_eip_address" {
}

resource "aws_nat_gateway" "ngw" {
  subnet_id = aws_subnet.public_subnet.id
  allocation_id = aws_eip.nat_gateway_eip_address.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.terraform_example.id

  route {
    cidr_block = "0.0.0.0/0" // dest
    gateway_id = aws_nat_gateway.ngw.id // target
  }

  tags = {
    Name = "Private Route Table"
  }
}

resource "aws_route_table_association" "private_route_table_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# ========== IGW and required routes for traffic to reach the internet

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.terraform_example.id

}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.terraform_example.id

  route {
    cidr_block = "0.0.0.0/0" // dest
    gateway_id = aws_internet_gateway.igw.id // target
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public_route_table_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# ========== ASG config

resource "aws_launch_configuration" "launch_config" {
  name            = "launch_config"
  image_id        = "ami-0e84abb22ec78250c"
  instance_type   = "t2.micro"
  security_groups = [ aws_security_group.instance_security_group.id ]

  user_data = <<-EOF
  #!/bin/bash
  yum update -y
  yum install httpd -y
  service start httpd
  chkconfig httpd on
  EOF
}

resource "aws_security_group" "instance_security_group" {
  name = "instance_security_group"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "TCP"
    security_groups = [ aws_security_group.alb_security_group.id ]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = [ "0.0.0.0/0" ]
  }
}

resource "aws_autoscaling_group" "asg" {
  launch_configuration = aws_launch_configuration.launch_config.id
  availability_zones   = [ var.private_az ]

  load_balancers    = [ aws_elb.elb.name ]
  health_check_type = "ELB"

  min_size         = 2
  max_size         = 3
  desired_capacity = 2

  tag {
    key                 = "Name"
    value               = "terraform_example"
    propagate_at_launch = true
  }
}

# ========== ELB

resource "aws_security_group" "alb_security_group" {
  name = "alb_security_group"

  ingress {
    from_port   = var.elb_port
    to_port     = var.elb_port
    protocol    = "TCP"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_lb" "alb" {
  name               = "alb"
  load_balancer_type = "application"
  security_groups    = [ aws_security_group.alb_security_group.id ]
  subnets            = [ aws_subnet.public_subnet.id ]
  internal           = false


}

resource "aws_elb" "elb" {
  name               = "elb"
  availability_zones = [ var.public_az ]
  security_groups    = [ aws_security_group.alb_security_group.id ]

  listener {
    lb_port           = var.elb_port
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 5
    target              = "HTTP:${var.server_port}/"
  }

  depends_on = [ aws_internet_gateway.igw ]
}

# ========== vars

variable vpc_address_space {
  description = "Address space of the VPC"
  default     = "10.0.0.0/16"
}

variable "public_az" {
  description = "AZ in which public facing ELB will live"
  default     = "us-east-2a"
}

variable "private_az" {
  description = "AZ in which private instances will live"
  default     = "us-east-2b"
}

variable "public_subnet_address_space" {
  description = "Address space of the public subnet"
  default     = "10.0.1.0/24"
}

variable "private_subnet_address_space" {
  description = "Address space of the private subnet"
  default     = "10.0.2.0/24"
}

variable "server_port" {
	description = "The port the server will listen on for HTTP requests"
	default     = 8080
}

variable "elb_port" {
  description = "The port the ELB will listen on for HTTP requests"
  default     = 80
}

# ========== outputs

output "elb_dns_name" {
	value = aws_elb.elb.dns_name
}
