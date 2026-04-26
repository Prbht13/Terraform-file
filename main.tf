provider "aws" {
  region = "us-east-1"
}

########################
# VPC
########################
resource "aws_vpc" "prakash_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "prakash-vpc"
  }
}

########################
# Subnets
########################
resource "aws_subnet" "prakash_subnet" {
  count = 2

  vpc_id            = aws_vpc.prakash_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.prakash_vpc.cidr_block, 8, count.index)
  availability_zone = element(["us-east-1a", "us-east-1b"], count.index)

  map_public_ip_on_launch = true

  tags = {
    Name = "prakash-subnet-${count.index}"
  }
}

########################
# Internet Gateway
########################
resource "aws_internet_gateway" "prakash_igw" {
  vpc_id = aws_vpc.prakash_vpc.id

  tags = {
    Name = "prakash-igw"
  }
}

########################
# Route Table
########################
resource "aws_route_table" "prakash_rt" {
  vpc_id = aws_vpc.prakash_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prakash_igw.id
  }

  tags = {
    Name = "prakash-rt"
  }
}

resource "aws_route_table_association" "prakash_rta" {
  count = 2

  subnet_id      = aws_subnet.prakash_subnet[count.index].id
  route_table_id = aws_route_table.prakash_rt.id
}

########################
# Security Groups
########################
resource "aws_security_group" "cluster_sg" {
  vpc_id = aws_vpc.prakash_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prakash-cluster-sg"
  }
}

resource "aws_security_group" "node_sg" {
  vpc_id = aws_vpc.prakash_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # tighten later
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prakash-node-sg"
  }
}

########################
# IAM Roles
########################
resource "aws_iam_role" "cluster_role" {
  name = "prakash-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "node_role" {
  name = "prakash-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

########################
# EKS Cluster
########################
resource "aws_eks_cluster" "prakash" {
  name     = "prakash-eks-cluster"
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.prakash_subnet[*].id
    security_group_ids = [aws_security_group.cluster_sg.id]
  }
}

########################
# Node Group
########################
resource "aws_eks_node_group" "prakash" {
  cluster_name    = aws_eks_cluster.prakash.name
  node_group_name = "prakash-node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = aws_subnet.prakash_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t3.medium"]

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.node_sg.id]
  }
}
