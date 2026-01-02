variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "location" {
  description = "GCP zone for the management cluster (e.g., us-central1-a)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "pods_range_name" {
  description = "Pods secondary IP range name"
  type        = string
}

variable "services_range_name" {
  description = "Services secondary IP range name"
  type        = string
}

variable "service_account_email" {
  description = "Service account for GKE nodes"
  type        = string
}

variable "enable_private_nodes" {
  description = "Enable private nodes"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr" {
  description = "Master IPv4 CIDR block"
  type        = string
  default     = "172.16.0.0/28"
}

variable "machine_type" {
  description = "Machine type for management cluster nodes"
  type        = string
  default     = "e2-micro"
}

variable "initial_node_count" {
  description = "Initial number of nodes in the management cluster (bootstrap only)"
  type        = number
  default     = 1
}

variable "node_count" {
  description = "Actual number of nodes in the management pool"
  type        = number
  default     = 1
}
