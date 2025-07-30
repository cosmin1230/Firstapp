# Outputs to display the created resources
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private_subnet[*].id
}

output "nat_gateway_id" {
  description = "The IDs of the NAT Gateways"
  value = {
    for k, nat in aws_nat_gateway.nat_gateway : k => nat.id
  }
}

output "nat_eip_public_ips" {
  description = "List of Elastic IPs for NAT Gateways"
  value = {
    for k, eip in aws_eip.nat_eip : k => eip.public_ip
  }
}

output "azs" {
  description = "A list of availability zones in which the VPC subnets were created."
  value       = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}