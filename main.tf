provider "aws" {
  region = "us-east-1"
}

# Data source to look up the manually created IAM role
data "aws_iam_role" "terra_role" {
  role_name = "Terraform_EKS"
}

resource "aws_vpc" "tera_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name          = "terraform_prod-vpc"
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

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
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
  role_arn = data.aws_iam_role.terra_role.arn  # Referencing the role ARN dynamically

  vpc_config {
    subnet_ids         = aws_subnet.tera_subnet[*].id
    security_group_ids = [aws_security_group.tera_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "tera_node_group" {
  cluster_name    = aws_eks_cluster.tera_cluster.name
  node_group_name = "tera-node-group"
  node_role_arn   = data.aws_iam_role.terra_role.arn  # Referencing the role ARN dynamically
  subnet_ids      = [aws_subnet.tera_subnet[0].id, aws_subnet.tera_subnet[1].id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  remote_access {
    ec2_ssh_key              = var.ssh_key_name  # Ensure the variable 'ssh_key_name' is defined
    source_security_group_ids = [aws_security_group.tera_node_sg.id]
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = data.aws_iam_role.terra_role.name  # Referencing the role name dynamically
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = data.aws_iam_role.terra_role.name  # Referencing the role name dynamically
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = data.aws_iam_role.terra_role.name  # Referencing the role name dynamically
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_security_group_rule" "eks_allow_nodes" {
  type                        = "ingress"
  from_port                   = 0
  to_port                     = 65535
  protocol                    = "tcp"
  security_group_id           = aws_security_group.tera_node_sg.id
  source_security_group_id    = aws_security_group.tera_cluster_sg.id
}


