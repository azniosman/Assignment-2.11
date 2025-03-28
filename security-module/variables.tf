variable "sec_group_name" {
  description = "Name of EC2 security group"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of allowed CIDR blocks for security group access"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "local_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}

variable "blocked_country_codes" {
  description = "List of country codes to block in WAF geo-restriction rule"
  type        = list(string)
  default     = []  # Empty list by default, allowing all countries
  validation {
    condition     = length(var.blocked_country_codes) <= 200
    error_message = "Maximum of 200 country codes can be specified for geo-restriction."
  }
  validation {
    condition     = alltrue([for code in var.blocked_country_codes : can(regex("^[A-Z]{2}$", code))])
    error_message = "Country codes must be in ISO 3166-1 alpha-2 format (e.g., 'US', 'GB')."
  }
}
