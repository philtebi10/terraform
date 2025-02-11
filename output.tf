output "cluster_id" {
  value = aws_eks_cluster.tera_cluster.id
}

output "node_group_id" {
  value = aws_eks_node_group.tera_node_group.id
}

output "vpc_id" {
  value = aws_vpc.tera_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.tera_subnet[*].id
}
