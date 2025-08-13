##########################################
############### Network ##################
##########################################
module "vpc" {
  source                               = "terraform-aws-modules/vpc/aws"
  version                              = "5.21.0"
  name                                 = var.project_name
  cidr                                 = var.cidr_vpc
  azs                                  = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets                      = [for k, v in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.cidr_vpc, 8, k)]
  public_subnets                       = [for k, v in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.cidr_vpc, 8, k + 4)]
  manage_default_network_acl           = false
  manage_default_route_table           = false
  manage_default_security_group        = false
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_nat_gateway                   = true
  one_nat_gateway_per_az               = true
  enable_flow_log                      = true
  vpc_flow_log_iam_role_name           = "${var.project_name}-vpc-flow-log-role"
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60
  public_subnet_tags = merge(var.tags, {
    "kubernetes.io/role/elb" = "1"
  })
  private_subnet_tags = merge(var.tags, {
    "kubernetes.io/role/internal-elb"                      = "1",
    "karpenter.sh/discovery"                               = "${var.project_name}_${var.env}"
    "kubernetes.io/cluster/${var.project_name}_${var.env}" = "shared"
  })
}

##########################################
################# EKS ####################
##########################################
module "cluster_autoscaler_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.12.1"
  name    = "cluster-autoscaler"

  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = ["foo"]
  # Pod Identity Associations
  association_defaults = {
    namespace       = "kube-system"
    service_account = "cluster-autoscaler-aws-cluster-autoscaler"
  }
  associations = {
    ex-one = {
      cluster_name = module.eks.cluster_name
    }
  }
  tags = {
    Environment = "dev"
  }
}
module "eks" {
  source                               = "terraform-aws-modules/eks/aws"
  version                              = "v20.37.2"
  vpc_id                               = module.vpc.vpc_id
  subnet_ids                           = module.vpc.private_subnets
  cluster_name                         = "${var.project_name}_${var.env}"
  cluster_version                      = var.cluster_version
  eks_managed_node_groups              = var.eks_managed_node_groups
  eks_managed_node_group_defaults      = local.eks_managed_node_group_defaults
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  access_entries                       = local.access_entries
  kms_key_administrators               = local.kms_key_administrators
  cluster_endpoint_public_access       = true
  cluster_addons = {
    vpc-cni = { most_recent = true
      before_compute = true
    }
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    aws-ebs-csi-driver     = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }

  }
}

##########################################
########### cluster-autoscaler ###########
##########################################
resource "helm_release" "cluster-autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.50.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  depends_on = [module.eks]
}
