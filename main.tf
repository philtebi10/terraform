# main.tf
provider "aws" {
  region = var.aws_region
}

# Fetch IAM role dynamically
data "aws_iam_role" "eks_role" {
  name = "Terraform_EKS"
}

# Create a VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }
}

# Enable VPC Flow Logs for monitoring
resource "aws_flow_log" "eks_vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.eks_vpc_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id              = aws_vpc.eks_vpc.id
}

resource "aws_cloudwatch_log_group" "eks_vpc_logs" {
  name = "/aws/eks/vpc-flow-logs"
  retention_in_days = 30
}

# Create an internet gateway
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks-igw"
  }
}

# Create a route table
resource "aws_route_table" "eks_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks-route-table"
  }
}

# Associate subnets with route table
resource "aws_route_table_association" "eks_rta" {
  for_each = toset(var.subnet_ids)
  subnet_id      = each.value
  route_table_id = aws_route_table.eks_rt.id
}

# Create security group for EKS with restricted access
resource "aws_security_group" "eks_sg" {
  vpc_id = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-sg"
  }
}

# Enable encryption for Kubernetes secrets
resource "aws_kms_key" "eks_kms" {
  description             = "KMS key for EKS secrets encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = var.subnet_ids
    security_group_ids = [aws_security_group.eks_sg.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_kms.arn
    }
    resources = ["secrets"]
  }
}

resource "aws_eks_node_group" "eks_nodes" {
  cluster_name  = aws_eks_cluster.eks.name
  node_group_name = var.node_group_name
  node_role_arn = data.aws_iam_role.eks_role.arn
  subnet_ids    = var.subnet_ids
  instance_types = var.instance_types
  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_capacity
    min_size     = var.min_capacity
  }
}

# Deploy AWS Load Balancer Controller
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = data.aws_iam_role.eks_role.arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_controller.metadata[0].name
  }
}
}


