terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_all_inbound_from_self" {
  security_group_id = var.sg_id
  referenced_security_group_id = var.sg_id
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_all_inbound_from_vpc" {
  security_group_id = var.sg_id
  cidr_ipv4   = var.cidr_ipv4
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_all_inbound_from_secondary_vpc" {
  security_group_id = var.sg_id
  cidr_ipv4   = var.secondary_cidr_ipv4
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_access" {
  security_group_id = var.sg_id
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "TCP"
  from_port   = 22
  to_port     = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_ipv4" {
  security_group_id = var.sg_id
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_ipv6" {
  security_group_id = var.sg_id
  cidr_ipv6   = "::/0"
  ip_protocol = "-1"
}
