terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.1"
      configuration_aliases = [aws.default, aws.region2, aws.region3]
    }
  }
}

data "aws_ami" "default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_filter]
  }
  provider = aws.default
}

data "aws_ami" "region2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_filter]
  }
  provider = aws.region2
}

data "aws_ami" "region3" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_filter]
  }
  provider = aws.region3
}

resource "aws_network_interface" "default" {
  count             = lookup(var.region_aliases, var.region) == "default" ? 1 : 0
  subnet_id         = var.subnet_id
  security_groups   = [var.security_group_id]
  private_ips_count = var.ip_alias_count
}

resource "aws_instance" "default" {
  count                = lookup(var.region_aliases, var.region) == "default" ? 1 : 0
  ami                  = data.aws_ami.default.id
  instance_type        = var.instance_type
  iam_instance_profile = "${var.prefix}-${var.region}"
  key_name             = var.prefix
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.default[0].id
  }
  user_data = templatefile("${path.module}/templates/user_data.tpl",
    {
      extra    = var.extra_user_data
      hostname = var.hostname
  })

  tags = {
    Name = var.instance_name
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
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }
  provider = aws.default
}

resource "aws_network_interface" "region2" {
  count             = lookup(var.region_aliases, var.region) == "region2" ? 1 : 0
  subnet_id         = var.subnet_id
  security_groups   = [var.security_group_id]
  private_ips_count = var.ip_alias_count
}

resource "aws_instance" "region2" {
  count                = lookup(var.region_aliases, var.region) == "region2" ? 1 : 0
  ami                  = data.aws_ami.region2.id
  instance_type        = var.instance_type
  iam_instance_profile = "${var.prefix}-${var.region}"
  key_name             = var.prefix
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.default[0].id
  }
  user_data = templatefile("${path.module}/templates/user_data.tpl",
    {
      extra    = var.extra_user_data
      hostname = var.hostname
  })

  tags = {
    Name = var.instance_name
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
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }
  provider = aws.region2
}

resource "aws_network_interface" "region3" {
  count             = lookup(var.region_aliases, var.region) == "region3" ? 1 : 0
  subnet_id         = var.subnet_id
  security_groups   = [var.security_group_id]
  private_ips_count = var.ip_alias_count
}

resource "aws_instance" "region3" {
  count                = lookup(var.region_aliases, var.region) == "region3" ? 1 : 0
  ami                  = data.aws_ami.region3.id
  instance_type        = var.instance_type
  iam_instance_profile = "${var.prefix}-${var.region}"
  key_name             = var.prefix
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.default[0].id
  }
  user_data = templatefile("${path.module}/templates/user_data.tpl",
    {
      extra    = var.extra_user_data
      hostname = var.hostname
  })

  tags = {
    Name = var.instance_name
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
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }
  provider = aws.region3
}

resource "aws_route53_record" "dns" {
  zone_id = var.route53_zone_id
  name    = var.hostname
  type    = "A"
  ttl     = 30
  records = concat(
    [for i in aws_instance.default : i.private_ip],
    [for i in aws_instance.region2 : i.private_ip],
    [for i in aws_instance.region3 : i.private_ip]
  )
  provider = aws.default
}
