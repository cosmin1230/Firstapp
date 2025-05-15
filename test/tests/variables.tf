variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "vpc_name" {
  default = "test-vpc"
}

variable "az_count" {
  type = number
}

variable "enable_public_subnets" {
  type = bool
}

variable "enable_private_subnets" {
  type = bool
}
