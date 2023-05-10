resource "aws_lb" "mqtt" {
  name               = "${var.namespace}-mqtt-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.nlb_sg.id]
}

resource "aws_lb_listener" "mqtt" {
  load_balancer_arn = aws_lb.mqtt.arn
  port              = "1883"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mqtt.arn
  }
}

resource "aws_lb_target_group" "mqtt" {
  name     = "${var.namespace}-mqtt-tg"
  port     = 1883
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "mqtt" {
  count            = length(var.instance_ids)
  target_group_arn = aws_lb_target_group.mqtt.arn
  target_id        = var.instance_ids[count.index]
  port             = 1883
}

resource "aws_security_group" "nlb_sg" {
  name_prefix = var.namespace
  description = "Security group for EMQX MQTT LB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    security_groups = [var.instance_sg_id]
  }
}
