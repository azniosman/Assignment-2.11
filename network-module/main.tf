## Creates a VPC resource with 1 Private Subnets
resource "aws_vpc" "s3_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = merge(var.common_tags, {
    Name = "${var.local_prefix}"
  })
}

## Creates the first private subnet in AZ1
resource "aws_subnet" "my_private_subnet_az1" {
  vpc_id     = aws_vpc.s3_vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone

  tags = merge(var.common_tags, {
    Name = "${var.local_prefix}-private-subnet-az1"
  })
}

## Creates an IGW for your VPC
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.s3_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.local_prefix}-tf-igw"
  })
}

## Creates a private route table for az1
resource "aws_route_table" "my_private_route_table_az1" {
  vpc_id = aws_vpc.s3_vpc.id

  route {
    cidr_block = aws_vpc.s3_vpc.cidr_block
    gateway_id = "local"
  }

  tags = merge(var.common_tags, {
    Name = "${var.local_prefix}-tf-private-rtb-az1"
  })
}

## Associate private route table to the private subnets accordingly
resource "aws_route_table_association" "first_private_assoc" {
  subnet_id      = aws_subnet.my_private_subnet_az1.id
  route_table_id = aws_route_table.my_private_route_table_az1.id
}

# Create a VPC Endpoint for S3 access
resource "aws_vpc_endpoint" "s3_vpce" {
  vpc_id       = aws_vpc.s3_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.my_private_route_table_az1.id]
  
  tags = merge(var.common_tags, {
    Name = "${var.local_prefix}-s3-vpce"
  })
}

