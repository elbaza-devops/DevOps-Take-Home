locals {
  access_entries = {
    Administrators = {
      principal_arn = "${data.aws_caller_identity.current.arn}"
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
  kms_key_administrators = ["${data.aws_caller_identity.current.arn}"]
  eks_managed_node_group_defaults = {
    use_custom_launch_template = true
    enable_bootstrap_user_data = true
    ami_type                   = "AL2023_x86_64_STANDARD"
    cloudinit_pre_nodeadm = [
      {
        content_type = "application/node.eks.aws"
        content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  shutdownGracePeriod: 30s
                  featureGates:
                    DisableKubeletCloudCredentialProviders: true
                flags:
                  - --node-labels=terraform-managed=true,cluster-name=${var.project_name}_${var.env}
          EOT
      },
      {
        content_type = "text/x-shellscript"
        content      = <<-EOT
            #!/bin/bash
            echo "Instance Initialization Script"
          EOT
      }
    ]
    cloudinit_post_nodeadm = [
      {
        content_type = "text/x-shellscript"
        content      = <<-EOT
            #!/bin/bash
            echo "Post Instance Initialization Script"
          EOT
      }
    ]

  }
}
