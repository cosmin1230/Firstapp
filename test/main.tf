# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = merge(var.common_tags, {
    Name = var.vpc_name
  })
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = merge(var.common_tags, {
    Name = var.igw_name
  })
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.public_subnet_cidr
  availability_zone = var.public_subnet_az
  map_public_ip_on_launch = var.public_subnet_map_public_ip

  tags = merge(var.common_tags, {
    Name = var.public_subnet_name
  })
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.private_subnet_cidr
  availability_zone = var.private_subnet_az
  
  tags = merge(var.common_tags, {
    Name = var.private_subnet_name
  })
}

# Create a public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = merge(var.common_tags, {
    Name = var.public_route_table_name
  })
}

# Create a private route table  
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = merge(var.common_tags, {
    Name = var.private_route_table_name
  })
}

# Create a NAT Gateway
# EIP for the NAT Gateway
resource "eip" "my_eip" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = var.eip_name
  })

  depends_on = [
    aws_internet_gateway.my_igw
   ]
}

resource "nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = merge(var.common_tags, {
    Name = var.nat_gateway_name
  })

  depends_on = [
    aws_internet_gateway.my_igw
  ]
}

# Update the private route table to direct outbound traffic to the NAT Gateway
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
  
  depends_on = [
    aws_nat_gateway.my_nat_gateway
  ]
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
} 

# Associate the private route table with the private subnet
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# Create Security Groups
# Create a security group for the public subnet
resource "security_group" "public_sg" {
  name = var.public_sg_name
  description = "Public Subnet Security Group"
  vpc_id = aws_vpc.my_vpc.id

  tags = merge(var.common_tags, {
    Name = var.public_sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "public_sg_ingress" {
  security_group_id = aws_security_group.public_sg.id
  
  cidr_ipv4   = var.sg_ingress_cidr
  ip_protocol = -1
}

resource "aws_vpc_security_group_egress_rule" "public_sg_egress" {
  security_group_id = aws_security_group.public_sg.id
  
  cidr_ipv4   = var.sg_egress_cidr
  ip_protocol = -1
}

# Create a security group for the private subnet
resource "aws_security_group" "private_sg" {
  name = var.private_sg_name
  description = "Private Subnet Security Group"
  vpc_id = aws_vpc.my_vpc.id

  tags = merge(var.common_tags, {
    Name = var.private_sg_name
  })
}

resource "aws_vpc_security_group_egress_rule" "private_sg_egress" {
  security_group_id = aws_security_group.private_sg.id
  
  cidr_ipv4   = var.sg_egress_cidr
  ip_protocol = -1
}

# Outputs to display the created resources
output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.private_subnet.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.my_nat_gateway.id
}