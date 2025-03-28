output "waf_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.waf_acl.arn
}

output "security_group_id" {
  description = "ID of the created security group"
  value       = aws_security_group.vpc_security.id
}

output "vpc_id" {
  description = "VPC ID passed through from network module"
  value       = var.vpc_id
}
