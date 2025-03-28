resource "aws_security_group" "vpc_security" {
  name        = var.sec_group_name
  vpc_id      = var.vpc_id
  description = "Security group allowing SSH, HTTP, and HTTPS access from specified CIDR blocks"
  
  tags = merge(var.common_tags, {
    Name = var.sec_group_name
  })

  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH access from specified CIDR"
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "HTTP access from specified CIDR"
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "HTTPS access from specified CIDR"
    }
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_wafv2_web_acl" "waf_acl" {
  name        = "azni-waf"
  description = "WAF for azni with enhanced security rules"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Geo Restriction
  rule {
    name     = "GeoMatchRule"
    priority = 1

    action {
      allow {}
    }

    statement {
      geo_match_statement {
        country_codes = ["US", "CA"]
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "azni-geo-match"
      sampled_requests_enabled   = true
    }
  }

  # Rate Limiting
  rule {
    name     = "RateLimiting"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = 2000
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "azni-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "azni-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.local_prefix}-waf"
  })
}

