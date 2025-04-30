variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "public_subnet_az" {
  description = "AZ for the public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "private_subnet_az" {
  description = "AZ for the private subnet"
  type        = string
  default     = "us-east-1b"
}

variable "public_subnet_map_public_ip" {
  description = "Assign public IP on launch for public subnet"
  type        = bool
  default     = true
}

variable "vpc_name" {
  description = "Base name for all resources"
  type        = string
  default     = "my_vpc"
}