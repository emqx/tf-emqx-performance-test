data "aws_ami" "ubuntu" {
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
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = var.sg_ids
  iam_instance_profile   = var.iam_profile
  user_data              = templatefile("${path.module}/templates/user_data.tpl",
    {
      s3_bucket_name = var.s3_bucket_name
      extra          = var.extra_user_data
    })

  tags = {
    Name = "${var.instance_name}-${count.index + 1}"
  }

  root_block_device {
    iops        = 3000
    throughput  = 125
    volume_size = 50
    volume_type = "gp3"
  }
}

resource "aws_route53_record" "dns" {
  count    = var.instance_count
  zone_id  = var.route53_zone_id
  name     = "${aws_instance.ec2[count.index].tags_all["Name"]}.${var.route53_zone_name}"
  type     = "A"
  ttl      = 30
  records  = [aws_instance.ec2[count.index].private_ip]
}
