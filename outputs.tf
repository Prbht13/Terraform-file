output "cluster_id" {
  value = aws_eks_cluster.prakash.id
}

output "node_group_id" {
  value = aws_eks_node_group.prakash.id
}

output "vpc_id" {
  value = aws_vpc.prakash_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.prakash_subnet[*].id
}
