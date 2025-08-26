output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.eks-cluster.id
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = aws_eks_cluster.eks-cluster.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.eks-cluster.certificate_authority[0].data
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.default.id
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.default.arn
}

output "node_group_status" {
  description = "EKS node group status"
  value       = aws_eks_node_group.default.status
}