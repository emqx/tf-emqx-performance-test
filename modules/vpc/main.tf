terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"
    }
  }
  required_version = ">= 1.2.0"
}

locals {
  ssh_key_name = var.prefix
}

data "aws_availability_zones" "available" {
  state = "available"
  provider = aws
}

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  provider = aws
  tags = {
    Name = var.prefix
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.cidr, 8, 0)
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]
  provider = aws
  tags = {
    Name = var.prefix
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  provider = aws
  tags = {
    Name = var.prefix
  }
}

resource "aws_route" "igw" {
  route_table_id = aws_vpc.vpc.main_route_table_id
  gateway_id     = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
  provider = aws
}

resource "aws_route" "igw_ipv6" {
  route_table_id = aws_vpc.vpc.main_route_table_id
  gateway_id     = aws_internet_gateway.igw.id
  destination_ipv6_cidr_block = "::/0"
  provider = aws
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_vpc.vpc.main_route_table_id
  provider = aws
}

resource "aws_security_group" "vpc_sg" {
  name        = "${var.prefix}-vpc-sg"
  description = "VPC security group"
  vpc_id      = aws_vpc.vpc.id
  provider = aws
}

resource "aws_key_pair" "kp" {
  key_name   = local.ssh_key_name
  public_key = var.public_key
  provider = aws
}
