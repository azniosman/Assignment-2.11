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

variable "source_repository_url" {
  description = "URL of the source code repository"
  type        = string
  default     = ""  # Set this in terraform.tfvars
}

locals {
  # Workspace-specific configurations
  environment_configs = {
    default = {
      environment = "dev"
      instance_type = "t2.micro"
    }
    staging = {
      environment = "staging"
      instance_type = "t2.medium"
    }
    production = {
      environment = "prod"
      instance_type = "t2.large"
    }
  }

  # Get current workspace configurations
  workspace_config = lookup(local.environment_configs, terraform.workspace, local.environment_configs["default"])
}

variable "local_prefix" {
  default = "azni"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "sec_group_name" {
  description = "Name of EC2 security group"
  type        = string
  default     = "azni-tf-sg-allow-ssh-http-https"
}

variable "allowed_cidr_blocks" {
  description = "List of allowed CIDR blocks for security group access"
  type        = list(string)
  validation {
    condition     = alltrue([
      for cidr in var.allowed_cidr_blocks : 
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$", cidr))
    ])
    error_message = "All CIDR blocks must be in valid format (e.g., 10.0.0.0/16)"
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-demo"
}

variable "cost_center" {
  description = "Cost center for resource billing"
  type        = string
  default     = "infrastructure"
}

variable "allowed_ports" {
  description = "List of allowed ports (must be between 1-65535)"
  type        = list(number)
  default     = [80, 443, 22]
  validation {
    condition     = alltrue([
      for port in var.allowed_ports :
      port > 0 && port < 65536
    ])
    error_message = "Ports must be between 1 and 65535."
  }
}

variable "retention_days" {
  description = "Number of days to retain CloudWatch logs (7-365 days)"
  type        = number
  default     = 30
  validation {
    condition     = var.retention_days >= 7 && var.retention_days <= 365
    error_message = "Retention days must be between 7 and 365."
  }
}
