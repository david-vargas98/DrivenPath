# Create Virtual Private Cloud.
resource "aws_vpc" "mwaa_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.tag
  }
}

# Create Internet Gateway.
resource "aws_internet_gateway" "mwaa_igw" {
  vpc_id = aws_vpc.mwaa_vpc.id
  tags = {
    Name = var.tag
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat1_eip" {
  domain = "vpc"
}

resource "aws_eip" "nat2_eip" {
  domain = "vpc"
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.mwaa_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.tag}-public-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.mwaa_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.tag}-public-2"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.mwaa_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "${var.tag}-private-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.mwaa_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "${var.tag}-private-2"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat1_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "${var.tag}-natgw-1"
  }
}

resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat2_eip.id
  subnet_id     = aws_subnet.public_subnet_2.id

  tags = {
    Name = "${var.tag}-natgw-2"
  }
}

# Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.mwaa_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mwaa_igw.id
  }

  tags = {
    Name = "${var.tag}-public-rt"
  }
}

resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.mwaa_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_1.id
  }

  tags = {
    Name = "${var.tag}-private-rt-1"
  }
}

resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.mwaa_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_2.id
  }

  tags = {
    Name = "${var.tag}-private-rt-2"
  }
}

# Subnet Associations
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table_1.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table_2.id
}

# Security Group
resource "aws_security_group" "mwaa_sg" {
  name        = "${var.tag}-sg"
  description = "Security group for MWAA access"
  vpc_id      = aws_vpc.mwaa_vpc.id

  # Allows HTTPS access from your personal IP
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.personal_public_ip]
  }

  # Allows inbound trafffic between components from the same SG (key rule for MWAA)
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true  # <- this creates the self-reference rule
  }

  # Outbound traffic to internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag}-sg"
  }
}

