provider "aws" {
  region = "us-east-1"
}

# Fetch the IAM role by name
data "aws_iam_role" "terra_role" {
  name = "Teraform_EKS"  # Provide the IAM role name here
}

resource "aws_eks_cluster" "tera_cluster" {
  name     = "tera-cluster"
  role_arn = data.aws_iam_role.terra_role.arn  # Reference the ARN of the IAM role

  vpc_config {
    subnet_ids         = aws_subnet.tera_subnet[*].id
    security_group_ids = [aws_security_group.tera_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "tera_node_group" {
  cluster_name    = aws_eks_cluster.tera_cluster.name
  node_group_name = "tera-node-group"
  node_role_arn   = data.aws_iam_role.terra_role.arn  # Reference the ARN of the IAM role
  subnet_ids      = [aws_subnet.tera_subnet[0].id, aws_subnet.tera_subnet[1].id]

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t3.medium"]

  remote_access {
    ec2_ssh_key              = var.ssh_key_name
    source_security_group_ids = [aws_security_group.tera_node_sg.id]
  }
}
