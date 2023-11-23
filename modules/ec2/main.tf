terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"
    }
  }
  required_version = ">= 1.2.0"
}

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_filter]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = var.sg_ids
  iam_instance_profile   = var.iam_profile
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  user_data              = templatefile("${path.module}/templates/user_data.tpl",
    {
      extra          = var.extra_user_data
      hostname       = var.hostname
    })

  tags = {
    Name = "${var.instance_name}"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  dynamic "instance_market_options" {
    for_each = var.use_spot_instances ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        spot_instance_type = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }

  provider = aws
}

resource "aws_route53_record" "dns" {
  zone_id  = var.route53_zone_id
  name     = var.hostname
  type     = "A"
  ttl      = 30
  records  = [aws_instance.ec2.private_ip]
}
