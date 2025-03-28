/**
* # Infrastructure Configuration
*
* ## Security Decisions
* 1. S3 Bucket:
*    - Server-side encryption enabled using AWS-managed keys (SSE-S3)
*    - Versioning enabled for data protection and recovery
*    - Public access blocked for security
*    - Lifecycle rules implemented for cost optimization
*
* 2. CloudFront:
*    - HTTPS-only access enforced
*    - TLSv1.2_2021 minimum protocol version
*    - Custom error responses for SPA support
*    - Geographic restrictions configurable
*
* 3. WAF Configuration:
*    - SQL Injection protection
*    - XSS protection
*    - Rate limiting to prevent DDoS
*    - IP-based restrictions
*
* 4. VPC Security:
*    - Private subnets for enhanced security
*    - S3 VPC Endpoint for secure access
*    - Security groups with principle of least privilege
*
* ## Resource Naming Convention
* - Format: {project}-{env}-{resource}
* - Environment from workspace: ${terraform.workspace}
* - Project prefix: ${var.local_prefix}
*/

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.s3_bucket.id

  rule {
    id     = "transition_to_intelligent_tiering"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    filter {
      prefix = ""  # Apply to all objects
    }
  }

  rule {
    id     = "expire_temp_uploads"
    status = "Enabled"

    expiration {
      days = 7
    }

    filter {
      prefix = "temp/"  # Apply to objects in temp/ prefix
    }
  }
}

locals {
  common_tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
  }

  s3_domain_name = "${var.local_prefix}.sctp-sandbox.com"
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = local.s3_domain_name
  force_destroy = true
  
  tags = merge(local.common_tags, {
    Name = "${var.local_prefix}-s3-bucket"
  })
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "s3_block" {
  bucket = aws_s3_bucket.s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Enable S3 bucket metrics
resource "aws_s3_bucket_metric" "bucket_metrics" {
  bucket = aws_s3_bucket.s3_bucket.id
  name   = "EntireBucket"
}

# CloudWatch alarms for S3 metrics
resource "aws_cloudwatch_metric_alarm" "s3_4xx_errors" {
  alarm_name          = "${var.local_prefix}-s3-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors S3 4xx errors"
  alarm_actions       = []  # Add SNS topic ARN if needed

  dimensions = {
    BucketName = aws_s3_bucket.s3_bucket.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "s3_5xx_errors" {
  alarm_name          = "${var.local_prefix}-s3-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors S3 5xx errors"
  alarm_actions       = []  # Add SNS topic ARN if needed

  dimensions = {
    BucketName = aws_s3_bucket.s3_bucket.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "s3_latency" {
  alarm_name          = "${var.local_prefix}-s3-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FirstByteLatency"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000"  # 1 second
  alarm_description   = "This metric monitors S3 first byte latency"
  alarm_actions       = []  # Add SNS topic ARN if needed

  dimensions = {
    BucketName = aws_s3_bucket.s3_bucket.id
  }

  tags = local.common_tags
}

## Network module for VPC, subnets, IGW, route tables, and endpoints
module "network" {
  source = "./network-module"
  
  local_prefix     = var.local_prefix
  aws_region       = var.aws_region
  vpc_cidr_block   = "10.0.0.0/16"
  subnet_cidr_block = "10.0.128.0/20"
  availability_zone = "us-east-1a"
  common_tags      = local.common_tags
}

# Attach a bucket policy allowing access via VPC Endpoint and Cloudfront interaction
resource "aws_s3_bucket_policy" "s3_policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowVPCAccess"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.s3_bucket.arn}/*"
        Condition = {
          StringEquals = { "aws:SourceVpc" = module.security.vpc_id }
        }
      },
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { "Service": "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.s3_bucket.arn}/*"
        Condition = {
          StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.cloudfront.arn }
        }
      }
    ]
  })
}

# IAM Role for accessing S3
resource "aws_iam_role" "s3_access_role" {
  name = "${var.local_prefix}-s3-role"
  
  tags = merge(local.common_tags, {
    Name = "${var.local_prefix}-s3-role"
  })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}


# IAM Policy for the role to access S3
resource "aws_iam_policy" "s3_access_policy" {
  name        = "${var.local_prefix}-s3-policy"
  description = "IAM Policy for accessing private S3 bucket"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
        Resource = ["${aws_s3_bucket.s3_bucket.arn}", "${aws_s3_bucket.s3_bucket.arn}/*"]
      }
    ]
  })
}


# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "s3_role_attach" {
  role       = aws_iam_role.s3_access_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

## Security module for security groups and WAF
module "security" {
  source = "./security-module"
  
  vpc_id               = module.network.vpc_id
  sec_group_name       = var.sec_group_name
  allowed_cidr_blocks  = var.allowed_cidr_blocks
  local_prefix         = var.local_prefix
  common_tags          = local.common_tags
  blocked_country_codes = var.blocked_country_codes
}


resource "aws_acm_certificate" "cert" {
  domain_name       = local.s3_domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.local_prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name              = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.s3_bucket.id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  aliases = [local.s3_domain_name]

  web_acl_id = module.security.waf_acl_arn

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.s3_bucket.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id  = aws_cloudfront_cache_policy.main.id
    compress = true

  }

  # Custom error response configurations
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.local_prefix}-cloudfront"
    Description = "CGPT TF CFS3"
  })

}
resource "aws_wafv2_web_acl" "waf_acl" {
  name        = "${var.local_prefix}-web-acl"
  description = "WAF Web ACL with security rules"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.local_prefix}-waf"
    sampled_requests_enabled   = true
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.local_prefix}-waf"
  })
}

resource "aws_route53_record" "dns_record" {
  zone_id = data.aws_route53_zone.sctp_zone.zone_id
  name    = local.s3_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "null_resource" "clone_git_repo" {
  provisioner "local-exec" {
    command = <<EOT
      git clone https://github.com/cloudacademy/static-website-example website_content
      aws s3 sync website_content s3://${aws_s3_bucket.s3_bucket.id} --exclude "*.MD" --exclude ".git*" --delete 
    EOT
  }
  
  # Ensures this runs after the S3 bucket is created
  depends_on = [aws_s3_bucket.s3_bucket]
}

resource "aws_cloudfront_cache_policy" "main" {
  name        = "${var.local_prefix}-cache-policy"
  comment     = "Cache policy for ${var.local_prefix}"
  default_ttl = 3600
  max_ttl     = 86400
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# CloudWatch Alarm for WAF blocked requests
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${var.local_prefix}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAF"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors blocked requests by WAF"
  alarm_actions       = []  # Add SNS topic ARN if needed
  
  dimensions = {
    WebACL = "${var.local_prefix}-waf"
    Rule   = "ALL"
  }

  tags = local.common_tags
}

output "vpc_id" {
  value = module.network.vpc_id
}
