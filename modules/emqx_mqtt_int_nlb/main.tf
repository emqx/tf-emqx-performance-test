resource "aws_lb" "nlb" {
  name               = var.nlb_name
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 1883
  protocol          = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.mqtt.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "mqtt" {
  name        = var.tg_name
  port        = 1883
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    interval            = 30
    port                = 1883
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "tga" {
  count            = length(var.instance_ids)
  target_group_arn = aws_lb_target_group.mqtt.arn
  port             = 1883
  target_id        = var.instance_ids[count.index]
}

