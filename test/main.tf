# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my_vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_igw"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"  
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  
  tags = {
    Name = "private_subnet"
  }
}

# Create a public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Create a private route table  
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private_route_table"
  }
}

# Create a NAT Gateway
# EIP for the NAT Gateway
resource "eip" "my_eip" {
  domain = "vpc"

  tags = {
    Name = "my_eip"
  }
  depends_on = [
    aws_internet_gateway.my_igw
   ]
}

resource "nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "my_nat_gateway"
  }

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
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "public_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_all__inbound_traffic" {
  security_group_id = aws_security_group.public_sg.id
  
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_traffic" {
  security_group_id = aws_security_group.public_sg.id
  
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

# Create a security group for the private subnet
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private_sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_traffic" {
  security_group_id = aws_security_group.private_sg.id
  
  cidr_ipv4   = "0.0.0.0/0"
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