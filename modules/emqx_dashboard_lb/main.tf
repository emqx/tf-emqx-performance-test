resource "aws_lb" "dashboard" {
  name               = "${var.namespace}-dashboard-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "dashbord" {
  load_balancer_arn = aws_lb.dashboard.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
  }
}

resource "aws_lb_target_group" "dashboard" {
  name     = "${var.namespace}-dashboard-tg"
  port     = 18083
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/status"
  }
}

resource "aws_lb_target_group_attachment" "dashboard" {
  count            = length(var.instance_ids)
  target_group_arn = aws_lb_target_group.dashboard.arn
  target_id        = var.instance_ids[count.index]
  port             = 18083
}

resource "aws_security_group" "alb_sg" {
  name_prefix = var.namespace
  description = "Security group for EMQX Dashboard LB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 18083
    to_port     = 18083
    protocol    = "tcp"
    security_groups = [var.instance_sg_id]
  }
}
