variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Base name for all resources"
  type        = string
  default     = "my_vpc"
}

variable "az_count" {
  description = "Number of AZs to deploy resources in (1-4)"
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 4
    error_message = "AZ count must be between 1 and 4."
  }
}

variable "enable_public_subnets" {
  description = "Whether to create public subnets"
  type        = bool
  default     = true
}

variable "enable_private_subnets" {
  description = "Whether to create private subnets"
  type        = bool
  default     = true
}