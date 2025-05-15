module "vpc" {
  source = "../"

  vpc_cidr_block         = var.vpc_cidr_block
  vpc_name               = var.vpc_name
  az_count               = var.az_count
  enable_public_subnets  = var.enable_public_subnets
  enable_private_subnets = var.enable_private_subnets
}
