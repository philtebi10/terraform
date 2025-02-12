# Output the EKS Cluster Name
output "EKS_TF" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

# Output the EKS Cluster Endpoint
output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

# Output the EKS Cluster ARN
output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.arn
}

# Output the EKS Worker Nodes Role ARN
output "eks_worker_role_arn" {
  description = "The ARN of the EKS worker node role"
  value       = aws_iam_role.eks_worker_role.arn
}
