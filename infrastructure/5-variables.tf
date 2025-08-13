##########################################
############### General ##################
##########################################
variable "project_name" {
  type = string
}
variable "env" {
  type = string
}
variable "tags" {
  type        = map(any)
  description = "Map of Default Tags"
}
variable "region" {
  type = string
}

##########################################
############### Network ##################
##########################################
variable "cidr_vpc" {
  type        = string
  description = "CIDR block for the VPC"

}
##########################################
################# EKS ####################
##########################################
variable "cluster_version" {
  type        = string
  description = "Version of the EKS cluster"
  default     = "1.32"
}
variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group configurations"
  type        = map(any)
}
variable "cluster_endpoint_public_access_cidrs" {
  type    = list(string)
}
variable "access_entries" {
  description = "Map of access entries to add to the cluster"
  type        = any
}