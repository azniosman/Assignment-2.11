# Backend config to store tfstate in an S3 bucket

terraform {
  backend "s3" {
    bucket = "azni"
    key    = "azni.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}