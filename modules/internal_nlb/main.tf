terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

resource "aws_lb" "nlb" {
  name                             = "${var.prefix}-internal-lb"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = var.subnet_ids
  security_groups                  = [aws_security_group.nlb_sg.id]
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "mqtt" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 1883
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.mqtt.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "mqtts" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8883
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.mqtts.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "ws" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8083
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.ws.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "httpapi" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = var.http_api_port
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.httpapi.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "http-extra" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8089
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.httpapi.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "mgmt" {
  count             = var.http_api_port != 18083 ? 1 : 0
  load_balancer_arn = aws_lb.nlb.arn
  port              = 18083
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.mgmt.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "mqtt" {
  name                              = "${var.prefix}-mqtt"
  port                              = 1883
  protocol                          = "TCP"
  vpc_id                            = var.vpc_id
  target_type                       = "instance"
  load_balancing_cross_zone_enabled = true
  health_check {
    interval            = 30
    port                = 1883
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "mqtts" {
  name                              = "${var.prefix}-mqtts"
  port                              = 8883
  protocol                          = "TCP"
  vpc_id                            = var.vpc_id
  target_type                       = "instance"
  load_balancing_cross_zone_enabled = true
  health_check {
    interval            = 30
    port                = 8883
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "ws" {
  name                              = "${var.prefix}-ws"
  port                              = 8083
  protocol                          = "TCP"
  vpc_id                            = var.vpc_id
  target_type                       = "instance"
  load_balancing_cross_zone_enabled = true
  health_check {
    interval            = 30
    port                = 8083
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "httpapi" {
  name                              = "${var.prefix}-httpapi"
  port                              = var.http_api_port
  protocol                          = "TCP"
  vpc_id                            = var.vpc_id
  target_type                       = "instance"
  load_balancing_cross_zone_enabled = true
  health_check {
    interval            = 30
    port                = var.http_api_port
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "mgmt" {
  name                              = "${var.prefix}-mgmt"
  port                              = 18083
  protocol                          = "TCP"
  vpc_id                            = var.vpc_id
  target_type                       = "instance"
  load_balancing_cross_zone_enabled = true
  health_check {
    interval            = 30
    port                = 18083
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_security_group" "nlb_sg" {
  name_prefix = var.prefix
  description = "Access to MQTT port"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = [1883, 8883, 8083, var.http_api_port, 18083]
    content {
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "TCP"
      cidr_blocks      = ["0.0.0.0/0"]
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
