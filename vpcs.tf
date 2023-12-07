locals {
  vpc_subnets = {
    (local.default_region) = {
      "public" = {
        "cidr" = cidrsubnet(var.vpc_cidr, 8, 0)
      }
    },
    (local.region2) = {
      "public" = {
        "cidr" = cidrsubnet(var.vpc_cidr, 8, 1)
      }
    },
    (local.region3) = {
      "public" = {
        "cidr" = cidrsubnet(var.vpc_cidr, 8, 2)
      }
    }
  }

  vpcs = {
    (local.default_region) = module.vpc-default
    (local.region2)        = local.region2 == "region2-stub" ? null : module.vpc-region2[0]
    (local.region3)        = local.region3 == "region3-stub" ? null : module.vpc-region3[0]
  }
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "pem_file" {
  filename             = local.ssh_key_path
  file_permission      = "600"
  directory_permission = "700"
  content              = tls_private_key.pk.private_key_pem
}

module "vpc-default" {
  source         = "./modules/vpc"
  vpc_region     = local.default_region
  provider_alias = "default"
  cidr           = local.vpc_subnets[local.default_region]["public"]["cidr"]
  prefix         = local.prefix
  public_key     = tls_private_key.pk.public_key_openssh
  providers = {
    aws = aws.default
  }
}

module "vpc-region2" {
  source         = "./modules/vpc"
  count          = local.region2 != "region2-stub" ? 1 : 0
  vpc_region     = local.region2
  provider_alias = "region2"
  cidr           = local.vpc_subnets[local.region2]["public"]["cidr"]
  prefix         = local.prefix
  public_key     = tls_private_key.pk.public_key_openssh
  providers = {
    aws = aws.region2
  }
}

module "vpc-region3" {
  source         = "./modules/vpc"
  count          = local.region3 != "region3-stub" ? 1 : 0
  vpc_region     = local.region3
  provider_alias = "region3"
  cidr           = local.vpc_subnets[local.region3]["public"]["cidr"]
  prefix         = local.prefix
  public_key     = tls_private_key.pk.public_key_openssh
  providers = {
    aws = aws.region3
  }
}

module "vpc-peering-default-to-region2" {
  source              = "./modules/vpc_peering"
  count               = local.region2 != "region2-stub" ? 1 : 0
  vpc_id              = module.vpc-default.vpc_id
  route_table_id      = module.vpc-default.main_route_table_id
  cidr_block          = local.vpc_subnets[local.default_region]["public"]["cidr"]
  peer_vpc_id         = module.vpc-region2[0].vpc_id
  peer_route_table_id = module.vpc-region2[0].main_route_table_id
  peer_region         = local.region2
  peer_cidr_block     = local.vpc_subnets[local.region2]["public"]["cidr"]
  providers = {
    aws.primary = aws.default
    aws.peer    = aws.region2
  }
}

module "vpc-peering-default-to-region3" {
  source              = "./modules/vpc_peering"
  count               = local.region3 != "region3-stub" ? 1 : 0
  vpc_id              = module.vpc-default.vpc_id
  route_table_id      = module.vpc-default.main_route_table_id
  cidr_block          = local.vpc_subnets[local.default_region]["public"]["cidr"]
  peer_vpc_id         = module.vpc-region3[0].vpc_id
  peer_route_table_id = module.vpc-region3[0].main_route_table_id
  peer_region         = local.region3
  peer_cidr_block     = local.vpc_subnets[local.region3]["public"]["cidr"]
  providers = {
    aws.primary = aws.default
    aws.peer    = aws.region3
  }
}

module "vpc-peering-region2-to-region3" {
  source              = "./modules/vpc_peering"
  count               = local.region2 != "region2-stub" && local.region3 != "region3-stub" ? 1 : 0
  vpc_id              = module.vpc-region2[0].vpc_id
  route_table_id      = module.vpc-region2[0].main_route_table_id
  cidr_block          = local.vpc_subnets[local.region2]["public"]["cidr"]
  peer_vpc_id         = module.vpc-region3[0].vpc_id
  peer_route_table_id = module.vpc-region3[0].main_route_table_id
  peer_region         = local.region3
  peer_cidr_block     = local.vpc_subnets[local.region3]["public"]["cidr"]
  providers = {
    aws.primary = aws.region2
    aws.peer    = aws.region3
  }
}

resource "aws_security_group_rule" "allow_access_from_public_nlb" {
  type                     = "ingress"
  security_group_id        = module.vpc-default.security_group_id
  source_security_group_id = module.public_nlb.security_group_id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
}

