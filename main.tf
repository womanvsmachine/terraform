terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.3.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_security_group" "tf-test-sg" {
  name    = "tf-test-sg"
  vpc_id  = var.vpc

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#resource "aws_instance" "tf-test" {
#  ami           	            = "ami-0817d428a6fb68645" # Ubuntu 18.04
#  instance_type 	            = "t2.micro"
#  subnet_id 	                = var.single_subnet
#  associate_public_ip_address = true
#  vpc_security_group_ids= [aws_security_group.tf-test-sg.id] # References resource tf-test-sg ID after being created in AWS
#  user_data = <<-EOF
#              #!/bin/bash
#              echo "Hello, World" > index.html
#              nohup busybox httpd -f -p ${var.server_port} &
#              EOF
#  tags = {
#  	Name = "tf-test"
#  }
#}

resource "aws_launch_configuration" "tf-test-lc" {
  image_id        = "ami-0817d428a6fb68645" # Ubuntu 18.04
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.tf-test-sg.id]
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  # Required when using a launch configuration with an auto scaling group
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html 
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "tf-test-asg" {
  launch_configuration  = aws_launch_configuration.tf-test-lc.name
  vpc_zone_identifier   = var.subnets
  target_group_arns     = [aws_lb_target_group.tf-test-asg-tg.arn]
  health_check_type     = "ELB" # More robust than default EC2 health check
  min_size              = 2
  max_size              = 10
  tag {
    key = "Name"
    value = "tf-test-asg"
    propagate_at_launch = true
  }
}

resource "aws_lb" "tf-test-alb" {
  name                = "tf-test-alb"
  load_balancer_type  = "application"
  subnets             = var.subnets
  security_groups     = [aws_security_group.tf-test-alb-sg.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn   = aws_lb.tf-test-alb.arn
  port                = 80
  protocol            = "HTTP"
  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
}

resource "aws_security_group" "tf-test-alb-sg" {
  name    = "tf-test-alb-sg"
  vpc_id  = var.vpc
  # Allow inbound HTTP requests
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "tf-test-asg-tg" {
  name      = "tf-test-asg-tg"
  port      = var.server_port
  protocol  = "HTTP"
  vpc_id    = var.vpc
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "tf-test-lb-listener-rule" {
  listener_arn  = aws_lb_listener.http.arn
  priority      = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type              = "forward"
    target_group_arn  = aws_lb_target_group.tf-test-asg-tg.arn
  }
}

#output "public_ip" {
#  value       = aws_instance.tf-test.public_ip
#  description = "The public IP address of the web server"
#}

output "alb_dns_name" {
  value       = aws_lb.tf-test-alb.dns_name
  description = "The domain name of the load balancer"
}