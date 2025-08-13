##########################################
############### General ##################
##########################################
project_name = "demo-project"
env          = "dev"
tags = {
  "Terraform"   = "true"
  "Environment" = "dev"
}
region = "us-east-1"

##########################################
############### Network ##################
##########################################
cidr_vpc = "10.0.0.0/16"

##########################################
################# EKS ####################
##########################################
cluster_version = "1.32"
eks_managed_node_groups = {
  "demo_project" = {
    desired_size   = 2
    min_size       = 1
    max_size       = 5
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 60
          volume_type           = "gp2"
          iops                  = 0
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
  }
}
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
access_entries = {
  Administrators = {
    principal_arn = "arn:aws:iam::448618645210:role/Administrator"
    policy_associations = {
      admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}
