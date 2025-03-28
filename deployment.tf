# Local variables for script paths and retry configuration
locals {
  scripts_path = "${path.module}/scripts"
  max_retries = 3
  retry_delay = 30
}

# Create the scripts directory if it doesn't exist
resource "null_resource" "setup_scripts" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.scripts_path}"
  }
}

# Create deployment script with retry logic
resource "local_file" "deploy_script" {
  depends_on = [null_resource.setup_scripts]
  filename   = "${local.scripts_path}/deploy.sh"
  content   = <<-EOF
#!/bin/bash
set -e

function retry {
  local max_attempts="$1"
  local delay="$2"
  shift 2
  local command="$@"
  local count=0
  until eval "$command" || [ $count -eq "$max_attempts" ]
  do
    echo "Command failed. Attempt $((count + 1)) of $max_attempts..."
    count=$((count + 1))
    sleep "$delay"
  done
  if [ $count -eq "$max_attempts" ]; then
    echo "Command failed after $max_attempts attempts"
    return 1
  fi
}

# Deployment steps with retry logic
echo "Starting deployment process..."

# Create dist directory if it doesn't exist
mkdir -p dist

# Create a sample index.html if it doesn't exist
if [ ! -f dist/index.html ]; then
  echo "<html><body><h1>Hello from S3 and CloudFront!</h1></body></html>" > dist/index.html
fi

# Sync files to S3 with retry
retry ${local.max_retries} ${local.retry_delay} "aws s3 sync dist/ s3://${aws_s3_bucket.s3_bucket.id}" || exit 1

echo "Deployment completed successfully"
EOF

  file_permission = "0755"
  directory_permission = "0755"
}

# Deployment execution with error handling
resource "null_resource" "deploy" {
  depends_on = [
    local_file.deploy_script,
    aws_s3_bucket.s3_bucket,
    aws_cloudfront_distribution.cloudfront
  ]

  triggers = {
    script_content = local_file.deploy_script.content
  }

  provisioner "local-exec" {
    command = "bash ${local_file.deploy_script.filename}"
  }
}
