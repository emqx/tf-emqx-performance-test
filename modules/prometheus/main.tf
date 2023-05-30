resource "aws_security_group" "instance_sg" {
  name        = "${var.namespace}-instance-sg"
  description = "Allow all inbound traffic withing sg, within VPC, external SSH access and all outbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    self             = true
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = var.cidr_blocks
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

module "prometheus_ec2" {
  source = "../ec2"

  namespace         = var.namespace
  instance_type     = var.instance_type
  instance_count    = 1
  ami_filter        = var.ami_filter
  sg_ids            = [aws_security_group.instance_sg.id]
  s3_bucket_name    = var.s3_bucket_name
  iam_profile       = var.iam_profile
  instance_name     = "${var.namespace}-prometheus"
  route53_zone_id   = var.route53_zone_id
  route53_zone_name = var.route53_zone_name
  key_name          = var.key_name
  subnet_id         = var.subnet_id
  extra_user_data   = templatefile("${path.module}/templates/user_data.tpl", {
    emqx_targets     = format("%#v", [for x in var.emqx_targets : "${x}:18083"])
    emqttb_targets   = format("%#v", [for x in var.emqttb_targets : "${x}:8017"])
    node_targets     = format("%#v", [for x in concat(var.emqx_targets, var.emqttb_targets) : "${x}:9100"])
    remote_write_url = var.remote_write_url
    remote_write_region = var.remote_write_region
  })
}
