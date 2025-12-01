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

variable "subnet_cidr" {
  description = "CIDR for GKE subnet"
  type        = string
}

variable "pods_cidr" {
  description = "CIDR for pods secondary range"
  type        = string
}

variable "services_cidr" {
  description = "CIDR for services secondary range"
  type        = string
}