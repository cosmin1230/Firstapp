terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "ecr"
  region = "us-east-1"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

locals {
  name         = var.cluster_name
  cluster_name = var.cluster_name
  region       = var.aws_region
  tags = merge(var.tags, {
    Terraform   = "true"
    Environment = var.environment
  })
}

# VPC Module
module "vpc" {
  source                 = "../terraform-modules/vpc-module"
  vpc_name               = "${local.name}-vpc"
  vpc_cidr_block         = var.vpc_cidr_block
  az_count               = var.az_count
  enable_public_subnets  = var.enable_public_subnets
  enable_private_subnets = var.enable_private_subnets
}

# EKS Module

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"

  # Give the Terraform identity admin access to the cluster
  # which will allow it to deploy resources into the cluster
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    # Enable after creation to run on Karpenter managed nodes
    coredns                = {
      addon_version = "v1.11.3-eksbuild.1"
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # Fargate profiles use the cluster primary security group
  # Therefore these are not used and can be skipped
  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profiles = {
    karpenter = {
      selectors = [{ namespace = "karpenter" }]
    }
    kube_system = {
      selectors = [{ namespace = "kube-system" }]
    }
    coredns = {
      name         = "coredns"
      cluster_name = local.cluster_name
      subnet_ids   = module.vpc.private_subnet_ids
      selectors = [{
        namespace = "kube-system"
      }]
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.cluster_name
  })
}

data "aws_eks_cluster" "eks_cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = module.eks.cluster_name
}

# Karpenter module
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.24"

  cluster_name          = module.eks.cluster_name
  enable_v1_permissions = true
  namespace             = "karpenter"

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = local.name

  # EKS Fargate does not support pod identity
  create_pod_identity_association = false
  enable_irsa                     = true
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn

  tags = local.tags
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token 
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
  load_config_file       = false
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

resource "helm_release" "karpenter" {
  name                = "karpenter"
  namespace           = "karpenter"
  create_namespace    = true
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.6.1"
  wait                = false

  values = [
    <<-EOT
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    webhook:
      enabled: false
    EOT
  ]

  lifecycle {
    ignore_changes = [
      repository_password
    ]
  }
  depends_on = [
    module.eks,
    module.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_config" {
  yaml_body = file("{$path.module}/karpenter.yaml")
  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.argocd_namespace
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = var.argocd_chart_version
  atomic     = true
  values     = [file("${path.module}/values.yaml")]
  depends_on = [kubernetes_namespace.argocd]
}

resource "kubectl_manifest" "app_of_apps" {
  yaml_body = file("${path.module}/app-of-apps.yaml")
  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.argocd
  ]
}