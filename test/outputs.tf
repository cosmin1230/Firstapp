# Outputs to display the created resources
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public_subnet[*].id
}

output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.private_subnet[*].id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.nat_gateway[*].id
}

output "nat_eip_public_ips" {
  description = "List of Elastic IPs for NAT Gateways"
  value       = aws_eip.nat_eip[*].public_ip
}