variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "region" {
  description = "GCP region"
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

# CPU Pool
variable "cpu_machine_type" {
  description = "Machine type for CPU nodes"
  type        = string
  default     = "n2-standard-8"
}

variable "cpu_min_nodes" {
  description = "Minimum CPU nodes"
  type        = number
  default     = 1
}

variable "cpu_max_nodes" {
  description = "Maximum CPU nodes"
  type        = number
  default     = 10
}

variable "use_preemptible" {
  description = "Use preemptible nodes"
  type        = bool
  default     = false
}

# GPU Pool
variable "enable_gpu_pool" {
  description = "Enable GPU node pool"
  type        = bool
  default     = false
}

variable "gpu_machine_type" {
  description = "Machine type for GPU nodes"
  type        = string
  default     = "n1-standard-8"
}

variable "gpu_type" {
  description = "GPU type"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_count" {
  description = "Number of GPUs per node"
  type        = number
  default     = 1
}

variable "gpu_min_nodes" {
  description = "Minimum GPU nodes"
  type        = number
  default     = 0
}

variable "gpu_max_nodes" {
  description = "Maximum GPU nodes"
  type        = number
  default     = 4
}