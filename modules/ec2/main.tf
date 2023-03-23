locals {
  timestamp = formatdate("DD-MMM-YYYY-hh:mm", timestamp())
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["${var.ami_filter}"]
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

resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2_policy"
  path        = "/"
  description = "Policy to provide permission to EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:List*"
        ],
        "Resource": [
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        "Resource": [
          "arn:aws:logs:*:*:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_policy_role" {
  name       = "ec2_attachment"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "ec2" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = var.sg_ids
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = templatefile("${path.module}/templates/user_data.tpl",
    {
      timestamp      = local.timestamp
      s3_bucket_name = var.s3_bucket_name
      extra          = var.extra_user_data
    })

  root_block_device {
    iops        = 3000
    throughput  = 125
    volume_size = 50
    volume_type = "gp3"
  }
}

# resource "null_resource" "emqx_cluster" {
#   count = local.emqx_rest_count

#   connection {
#     type        = "ssh"
#     host        = local.emqx_rest[count.index % local.emqx_rest_count]
#     user        = "ubuntu"
#     private_key = var.private_key
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "/home/ubuntu/emqx/bin/emqx_ctl cluster join emqx@${local.emqx_anchor}"
#     ]
#   }
# }
