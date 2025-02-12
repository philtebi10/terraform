# AWS Region to create resources in
variable "aws_region" {
  description = "AWS Region for EKS cluster"
  type        = string
  default     = "us-east-1"  # Replace with your desired region
}

# Name of the EKS cluster
variable "EKS_TF" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"  # Replace with your preferred cluster name
}
