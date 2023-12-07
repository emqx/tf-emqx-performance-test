terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"
      configuration_aliases = [ aws.primary, aws.peer ]
    }
  }
  required_version = ">= 1.2.0"
}

data "aws_caller_identity" "peer" {
  provider = aws.peer
}

resource "aws_vpc_peering_connection" "peer" {
  provider      = aws.primary
  vpc_id        = var.vpc_id
  peer_vpc_id   = var.peer_vpc_id
  peer_region   = var.peer_region
  peer_owner_id = data.aws_caller_identity.peer.account_id
  auto_accept   = false
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  provider = aws.peer
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept = true
}

resource "aws_vpc_peering_connection_options" "requester" {
  provider = aws.primary
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider = aws.peer
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "route_primary_to_peer" {
  provider = aws.primary
  route_table_id = var.route_table_id
  destination_cidr_block = var.peer_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "route_peer_to_primary" {
  provider = aws.peer
  route_table_id = var.peer_route_table_id
  destination_cidr_block = var.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}
