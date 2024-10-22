provider "aws" {
  region = "us-east-1"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

# Create the IAM role for EKS
resource "aws_iam_role" "eks_role" {
  name = "my-eks-cluster-eks-cluster-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach the AmazonEKSClusterPolicy
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

# Attach the AmazonEKSVPCResourceController policy
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_role.name
}

# Create the EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [
      "subnet-03f3cd99a48a2db7c",  # Add your actual subnet IDs here
      "subnet-001a3b80bd44fbbd4"   # Another subnet ID
    ]
  }

  # Additional cluster configurations can be added here
}

# Create the IAM role for EKS nodes
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach the necessary policies to the IAM role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Launch Template for EKS nodes
resource "aws_launch_template" "eks_node_launch_template" {
  name_prefix   = "eks-node-"
  image_id      = "ami-033e9014aebd5daca"
  instance_type = "t3.medium"

  key_name = "test1jenkins"

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -o xtrace
    /etc/eks/bootstrap.sh my-eks-cluster
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "eks-node"
    }
  }
}

# Create a node group for the EKS cluster
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "my-eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [
    "subnet-03f3cd99a48a2db7c",
    "subnet-001a3b80bd44fbbd4"
  ]

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.eks_node_launch_template.id
    version = "$Latest"
  }

  depends_on = [aws_eks_cluster.eks]
}
