resource "aws_security_group" "sg" {
  name        = "${var.namespace}-sg"
  description = "Allow all inbound traffic withing sg, external SSH access and all outbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    self = true
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = var.cidr_blocks
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
