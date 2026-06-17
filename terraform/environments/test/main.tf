terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    key = "test/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }

  cluster_name = "${var.project}-${var.environment}"
}

module "vpc" {
  source             = "../../modules/vpc"
  cidr               = var.vpc_cidr
  project            = var.project
  environment        = var.environment
  cluster_name       = local.cluster_name
  single_nat_gateway = true
  aws_account_id     = var.aws_account_id
  tags               = local.common_tags
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = local.cluster_name
  kubernetes_version = var.k8s_version
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  node_min           = 1
  node_max           = 3
  node_desired       = 1
  project            = var.project
  environment        = var.environment
  tags               = local.common_tags
}

module "bastion" {
  source           = "../../modules/ec2"
  project          = var.project
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  instance_type    = "t3.micro"
  tags             = local.common_tags
}

module "iam" {
  source          = "../../modules/iam"
  project         = var.project
  github_org      = var.github_org
  github_repo     = var.github_repo
  tf_state_bucket = var.tf_state_bucket
  tf_lock_table   = var.tf_lock_table
  tags            = local.common_tags
}
