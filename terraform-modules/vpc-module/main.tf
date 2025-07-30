data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_region" "current" {}

locals {
  newbits = var.az_count * 2
  
  public_subnet_cidrs = [
    for i in range(var.az_count) : 
    cidrsubnet(var.vpc_cidr_block, local.newbits, i)
  ]
  
  private_subnet_cidrs = [
    for i in range(var.az_count) :
    cidrsubnet(var.vpc_cidr_block, local.newbits, i + var.az_count)
  ]
  
  # Create NAT resources only if both public and private subnets are enabled
  create_nat = var.enable_private_subnets && var.enable_public_subnets
}

# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = var.vpc_name
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  count = var.enable_public_subnets ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  count = var.enable_public_subnets ? var.az_count : 0

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  count = var.enable_private_subnets ? var.az_count : 0

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.vpc_name}-private-subnet-${data.aws_availability_zones.available.names[count.index]}"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# Create a public route table
resource "aws_route_table" "public_route_table" {
  count = var.enable_public_subnets ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

# Create a private route table  
resource "aws_route_table" "private_route_table" {
  count = var.enable_private_subnets && var.enable_public_subnets ? var.az_count : 0

  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-private-rt-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# Create a NAT Gateway
# EIP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  count  = local.create_nat ? var.az_count : 0
  domain = "vpc"

  tags = {
    Name = "${var.vpc_name}-nat-eip-${data.aws_availability_zones.available.names[count.index]}"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = local.create_nat ? var.az_count : 0
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id

  tags = {
    Name = "${var.vpc_name}-nat-gw-${data.aws_availability_zones.available.names[count.index]}"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

# Update the private route table to direct outbound traffic to the NAT Gateway
resource "aws_route" "private_route" {
  count                  = var.enable_private_subnets && var.enable_public_subnets ? var.az_count : 0
  route_table_id         = aws_route_table.private_route_table[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway[count.index].id

  depends_on = [
    aws_nat_gateway.nat_gateway
  ]
}

# S3 VPC Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    var.enable_public_subnets ? aws_route_table.public_route_table[*].id : [],
    (var.enable_private_subnets && var.enable_public_subnets) ? aws_route_table.private_route_table[*].id : []
  )


  tags = {
    Name = "${var.vpc_name}-s3-endpoint"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_subnet_association" {
  count          = var.enable_public_subnets ? var.az_count : 0
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table[0].id
}

# Associate the private route table with the private subnet
resource "aws_route_table_association" "private_subnet_association" {
  count          = var.enable_private_subnets && var.enable_public_subnets ? var.az_count : 0
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table[count.index].id
}