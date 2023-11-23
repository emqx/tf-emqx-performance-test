resource "aws_lb" "nlb" {
  name               = "${var.prefix}-public-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.nlb_sg.id]
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

resource "aws_lb_target_group" "emqx" {
  name     = "${var.prefix}-emqx-tg"
  port     = 18083
  protocol = "TCP"
  target_type = "ip"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "emqx" {
  count = length(var.emqx_instance_ips)
  target_group_arn = aws_lb_target_group.emqx.arn
  target_id        = var.emqx_instance_ips[count.index]
  port             = 18083
}

resource "aws_lb_target_group" "grafana" {
  name     = "${var.prefix}-grafana-tg"
  port     = 3000
  protocol = "TCP"
  target_type = "ip"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "grafana" {
  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = var.monitoring_instance_ip
  port             = 3000
}

resource "aws_lb_target_group" "prometheus" {
  name     = "${var.prefix}-prometheus-tg"
  port     = 9090
  protocol = "TCP"
  target_type = "ip"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "prometheus" {
  target_group_arn = aws_lb_target_group.prometheus.arn
  target_id        = var.monitoring_instance_ip
  port             = 9090
}

resource "aws_security_group" "nlb_sg" {
  name_prefix = var.prefix
  description = "Access to EMQX Dashboard, Grafana and Prometheus"
  vpc_id      = var.vpc_id

  ingress {
    from_port        = 18083
    to_port          = 18083
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 3000
    to_port          = 3000
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 9090
    to_port          = 9090
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
