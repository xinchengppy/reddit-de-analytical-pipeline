variable "db_password" {
  description = "Password for Redshift master DB user"
  type        = string
  default     = "Lxc123456"
}

variable "s3_bucket" {
  description = "Bucket name for S3"
  type        = string
  default     = "xinchengluo-reddit-bucket"
}

variable "aws_region" {
  description = "Region for AWS"
  type        = string
  default     = "eu-west-3"
}