terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3" # Paris
}

# 1. THE VIRTUAL NETWORK (VPC)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "shield-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-3a", "eu-west-3b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# 2. THE KUBERNETES CLUSTER (EKS)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "shield-eks-cluster"
  cluster_version = "1.30"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.micro"]              # Changed from t3.medium to comply with Free Tier restrictions
      ami_type       = "AL2023_x86_64_STANDARD"  # Amazon Linux 2023 for EKS 1.30
    }
  }
}