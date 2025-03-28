variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.128.0/20"
}

variable "availability_zone" {
  description = "Availability Zone for subnet"
  type        = string
  default     = "us-east-1a"
}

variable "local_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}

