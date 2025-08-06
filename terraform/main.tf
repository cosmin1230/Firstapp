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
    "karpenter.sh/discovery" = local.cluster_name
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
  cluster_name = local.name
}

# EKS Module

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.22"

  cluster_name    = local.cluster_name
  cluster_version = "1.33"

  # Give the Terraform identity admin access to the cluster
  # which will allow it to deploy resources into the cluster
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true
  
  cluster_encryption_config = {
    enable_encryption = false
  }

  cluster_addons = {
    coredns                = {
      addon_version = "v1.12.2-eksbuild.4"
      configuration_values = jsonencode({
        computeType = "fargate"
        resources = {
          limits = {
            cpu    = "0.25"
            memory = "256M"
          }
          requests = {
            cpu    = "0.25"
            memory = "256M"
          }
        }
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
    coredns = {
      name         = "coredns"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        }
      ]
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.cluster_name
  })
}

data "aws_eks_cluster" "eks_cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${local.name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}

# Karpenter module
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.22"

  cluster_name          = module.eks.cluster_name
  namespace             = "karpenter"

  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix = false
  node_iam_role_name = "${local.name}-karpenter-node"

  create_pod_identity_association = false
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
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
  wait                = true
  atomic              = true

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: eks.amazonaws.com/compute-type
        operator: Equal
        value: fargate
        effect: NoSchedule
    controller:
      resources:
        requests:
          cpu: 1000m
          memory: 1024Mi
        limits:
          cpu: 1000m
          memory: 1024Mi
    EOT
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_config" {
  yaml_body = templatefile("${path.module}/karpenter.yaml", {
    node_iam_role_name   = module.karpenter.node_iam_role_name
    cluster_name         = module.eks.cluster_name
    availability_zones   = jsonencode(module.vpc.azs)
  })
  depends_on = [
    helm_release.karpenter
   ]
}

resource "kubectl_manifest" "karpenter_nodepool" {
  yaml_body = file("${path.module}/nodepool.yaml")
  depends_on = [
    kubectl_manifest.karpenter_config
   ]
}

resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  
  version    = "2.29.0"
  wait       = true
  atomic     = true

  values = [
    yamlencode({
      controller = {
        serviceAccount = {
          create = true
          name   = "ebs-csi-controller-sa"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_driver_role.arn
          }
        }
      }
    })
  ]

  depends_on = [
    kubectl_manifest.karpenter_nodepool
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
  depends_on = [kubernetes_namespace.argocd,
                module.eks,
                module.karpenter,
                helm_release.karpenter,
                resource.kubectl_manifest.karpenter_nodepool]
}

resource "kubectl_manifest" "app_of_apps" {
  yaml_body = file("${path.module}/app-of-apps.yaml")
  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.argocd
  ]
}