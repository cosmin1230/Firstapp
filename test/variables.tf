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

variable "sg_ingress_cidr" {
  description = "Allowed CIDR for inbound traffic"
  type        = string
  default     = "0.0.0.0/0"
}

variable "sg_egress_cidr" {
  description = "Allowed CIDR for outbound traffic"
  type        = string
  default     = "0.0.0.0/0"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "my-app"
  }
}

variable "vpc_name" {
  description = "Name tag for VPC"
  type        = string
  default     = "my_vpc"
}

variable "igw_name" {
  description = "Name tag for Internet Gateway"
  type        = string
  default     = "my_igw"
}

variable "public_subnet_name" {
  description = "Name tag for public subnet"
  type        = string
  default     = "public_subnet"
}

variable "private_subnet_name" {
  description = "Name tag for private subnet"
  type        = string
  default     = "private_subnet"
}

variable "public_route_table_name" {
  description = "Name tag for public route table"
  type        = string
  default     = "public_route_table"
}

variable "private_route_table_name" {
  description = "Name tag for private route table"
  type        = string
  default     = "private_route_table"
}

variable "nat_gateway_name" {
  description = "Name tag for NAT Gateway"
  type        = string
  default     = "my_nat_gw"
}

variable "eip_name" {
  description = "Name tag for Elastic IP"
  type        = string
  default     = "my_eip"
}

variable "public_sg_name" {
  description = "Name tag for public security group"
  type        = string
  default     = "public_sg"
}

variable "private_sg_name" {
  description = "Name tag for private security group"
  type        = string
  default     = "private_sg"
}