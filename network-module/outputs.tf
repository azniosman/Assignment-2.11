output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.s3_vpc.id
}

output "subnet_id" {
  description = "ID of the created private subnet"
  value       = aws_subnet.my_private_subnet_az1.id
}

output "route_table_id" {
  description = "ID of the created route table"
  value       = aws_route_table.my_private_route_table_az1.id
}

output "vpc_endpoint_id" {
  description = "ID of the created VPC endpoint"
  value       = aws_vpc_endpoint.s3_vpce.id
}

