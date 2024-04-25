terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"
    }
  }
}

resource "aws_lb" "nlb" {
  name                             = "${var.prefix}-public-lb"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = var.subnet_ids
  security_groups                  = [aws_security_group.nlb_sg.id]
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "emqx" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "18083"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.emqx.arn
  }
}

resource "aws_lb_listener" "emqx-ws" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "8083"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.emqx-ws.arn
  }
}

resource "aws_lb_listener" "emqx-api" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "8081"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.emqx-api.arn
  }
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "3000"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

resource "aws_lb_listener" "prometheus" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "9090"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
}

resource "aws_lb_listener" "locust" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "8080"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.locust.arn
  }
}

resource "aws_lb_target_group" "emqx" {
  name        = "${var.prefix}-emqx"
  port        = 18083
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group" "emqx-ws" {
  name        = "${var.prefix}-emqx-ws"
  port        = 8083
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group" "emqx-api" {
  name        = "${var.prefix}-emqx-api"
  port        = 8081
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.prefix}-grafana"
  port        = 3000
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group" "prometheus" {
  name        = "${var.prefix}-prometheus"
  port        = 9090
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb_target_group" "locust" {
  name        = "${var.prefix}-locust"
  port        = 8080
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "nlb_sg" {
  name_prefix = var.prefix
  description = "Access to EMQX Dashboard, Grafana and Prometheus"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = [18083, 8083, 8081, 3000, 9090, 8080]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
