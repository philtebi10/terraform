provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "tera_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform_prod-vpc"
    terraform_vpc = "true"
  }
}

resource "aws_subnet" "tera_subnet" {
  count = 2
  vpc_id                  = aws_vpc.tera_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.tera_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "tera_subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "tera_igw" {
  vpc_id = aws_vpc.tera_vpc.id

  tags = {
    Name = "tera-igw"
  }
}

resource "aws_route_table" "tera_route_table" {
  vpc_id = aws_vpc.tera_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tera_igw.id
  }

  tags = {
    Name = "tera-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.tera_subnet[count.index].id
  route_table_id = aws_route_table.tera_route_table.id
}

resource "aws_security_group" "tera_cluster_sg" {
  vpc_id = aws_vpc.tera_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tera-cluster-sg"
  }
}

resource "aws_security_group" "tera_node_sg" {
  vpc_id = aws_vpc.tera_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tera-node-sg"
  }
}

resource "aws_eks_cluster" "tera_cluster" {
  name     = "tera-cluster"
  role_arn = aws_iam_role.tera_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.tera_subnet[*].id
    security_group_ids = [aws_security_group.tera_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "tera_node_group" {
  cluster_name    = aws_eks_cluster.tera_cluster.name
  node_group_name = "tera-node-group"
  node_role_arn   = aws_iam_role.tera_node_group_role.arn
  subnet_ids      = aws_subnet.tera_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.large"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.tera_node_sg.id]
  }
}

resource "aws_iam_role" "tera_cluster_role" {
  name = "tera-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "tera_cluster_role_policy" {
  role       = aws_iam_role.tera_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "tera_node_group_role" {
  name = "tera-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_admin_role_admin" {
  role       = "Teraform_EKS"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "eks_admin_role_cluster" {
  role       = "Teraform_EKS"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_admin_role_service" {
  role       = "Teraform_EKS"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_admin_role_worker" {
  role       = "Teraform_EKS"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = "Teraform_EKS"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = "Teraform_EKS"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
