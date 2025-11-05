terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

data "aws_availability_zones" "available" {
  state    = "available"
  provider = aws
}

resource "aws_vpc" "vpc" {
  cidr_block                       = var.cidr
  assign_generated_ipv6_cidr_block = var.enable_ipv6
  enable_dns_hostnames             = true
  enable_dns_support               = true
  provider                         = aws
  tags = {
    Name = var.prefix
  }
}

data "aws_vpc" "vpc" {
  id = aws_vpc.vpc.id
}

resource "aws_subnet" "public" {
  count                           = length(data.aws_availability_zones.available.names)
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet(var.cidr, 8, count.index)
  ipv6_cidr_block                 = var.enable_ipv6 ? cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index) : null
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = var.enable_ipv6
  availability_zone               = data.aws_availability_zones.available.names[count.index]
  provider                        = aws
  tags = {
    Name = var.prefix
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id   = aws_vpc.vpc.id
  provider = aws
  tags = {
    Name = var.prefix
  }
}

resource "aws_route" "igw" {
  route_table_id         = aws_vpc.vpc.main_route_table_id
  gateway_id             = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
  provider               = aws
}

resource "aws_route" "igw_ipv6" {
  count                       = var.enable_ipv6 ? 1 : 0
  route_table_id              = aws_vpc.vpc.main_route_table_id
  gateway_id                  = aws_internet_gateway.igw.id
  destination_ipv6_cidr_block = "::/0"
  provider                    = aws
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_vpc.vpc.main_route_table_id
  provider       = aws
}

resource "aws_security_group" "vpc_sg" {
  name        = "${var.prefix}-vpc-sg"
  description = "VPC security group"
  vpc_id      = aws_vpc.vpc.id
  provider    = aws
}

resource "aws_key_pair" "kp" {
  key_name   = var.prefix
  public_key = var.public_key
  provider   = aws
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "${var.prefix}-${var.vpc_region}"
  path        = "/"
  description = "Policy to provide permission to EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:List*"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
  provider = aws
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.prefix}-${var.vpc_region}"

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
  provider = aws
}

resource "aws_iam_policy_attachment" "ec2_policy_role" {
  name       = "${var.prefix}-${var.vpc_region}"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = aws_iam_policy.ec2_policy.arn
  provider   = aws
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name     = "${var.prefix}-${var.vpc_region}"
  role     = aws_iam_role.ec2_role.name
  provider = aws
}

module "security_group_rules" {
  source            = "./../security_group_rules"
  cidr_ipv4         = "10.0.0.0/8"
  security_group_id = aws_security_group.vpc_sg.id
  enable_ipv6       = var.enable_ipv6
  providers = {
    aws = aws
  }
}
