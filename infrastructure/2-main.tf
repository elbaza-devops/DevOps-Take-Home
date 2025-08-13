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

module "aws_lb_controller_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.12.1"
  name = "aws-lbc"
  attach_aws_lb_controller_policy = true
  # Pod Identity Associations
  association_defaults = {
    namespace       = "kube-system"
    service_account = "aws-lb-controller-aws-load-balancer-controller"
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
############ AWS LoadBalancer ############
##########################################
# Fetch ALB CRDs (Custom Resource Definitions) from GitHub
data "http" "alb_crds" {
  # Conditional creation based on the enable flag in alb_config
  #   count = var.alb_config["enable"] ? 1 : 0
  url = "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml"
}
# Parse ALB CRDs YAML content
locals {
  alb_crds_yaml = split("---", data.http.alb_crds.body)
}
# Apply ALB CRDs to the Kubernetes cluster
resource "kubectl_manifest" "alb_crds" {
  yaml_body = data.http.alb_crds.body
  depends_on = [module.eks]
}
resource "helm_release" "aws_lb_controller" {
  name       = "aws-lb-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = "1.13.4"
  namespace  = "kube-system"
  depends_on = [module.eks]
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name = "autoDiscoverAwsRegion"
    value = "true"
  }
  set {
    name = "autoDiscoverAwsVpcID"
    value = "true"
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

##########################################
############# external-secrets ###########
##########################################
resource "helm_release" "external-secrets-operator" {
  name       = "external-secrets-operator"
  chart      = "external-secrets"
  repository = "https://charts.external-secrets.io"
  version    = "0.19.1"
  namespace  = "kube-system"
  depends_on = [module.eks]
}
module "external_secret_iam_assumable_role_with_oidc" {
  source           = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version          = "5.28.0"
  create_role      = true
  provider_url     = module.eks.oidc_provider
  role_name        = "external-secrets-operator-role"
  role_policy_arns = ["arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
}

##########################################
############### Metrics Server ###########
##########################################
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server"
  chart            = "metrics-server"
  version          = "3.12.2"
  namespace        = "kube-system"
  create_namespace = false
}

##########################################
######## Kube Prometheus Stack  ##########
##########################################
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "76.3.0"
  namespace        = "monitoring"
  create_namespace = true
  values           = [file("${path.module}/Helm-values/1-alert-manager.yaml")]
}