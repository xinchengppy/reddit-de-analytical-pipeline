terraform {
    required_version = ">= 1.13.0"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.6"
        }
    }
}

# Configure AWS provider
provider "aws" {
    region = var.aws_region
    profile = "default"
    default_tags {
      tags = {
        Project     = "Redshift-Pipeline"
        Environment = "dev"
        Owner       = "xcluo"
      }
    }
}

# Configure redshift cluster. This will fall under free tier as of November 2025.
resource "aws_redshift_cluster" "redshift" {
  cluster_identifier = "redshift-cluster-pipeline"
  skip_final_snapshot = true # must be set so we can destroy redshift with terraform destroy
  master_username    = "awsuser"
  master_password    = var.db_password
  node_type          = "ra3.xlplus"
  cluster_type       = "single-node"
  publicly_accessible = "true"
  iam_roles = [aws_iam_role.redshift_role.arn]
  vpc_security_group_ids = [aws_security_group.sg_redshift.id]
  tags = {
    Name = "Redshift-FreeTier"
  }
}

# Confuge security group for Redshift allowing all inbound/outbound traffic
 resource "aws_security_group" "sg_redshift" {
  name        = "sg_redshift"
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

# Create S3 Read only access role. This is assigned to Redshift cluster so that it can read data from S3

resource "aws_iam_role" "redshift_role" {
  name = "RedShiftLoadRole"
  assume_role_policy  = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_role_policy_attachment" "redshift_s3_readonly_attach" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
# resource "aws_iam_role" "redshift_role" {
#   name = "RedShiftLoadRole"
#   managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Sid    = ""
#         Principal = {
#           Service = "redshift.amazonaws.com"
#         }
#       },
#     ]
#   })
# }

# Create S3 bucket
resource "aws_s3_bucket" "reddit_bucket" {
  bucket = var.s3_bucket
  force_destroy = true # will delete contents of bucket when we run terraform destroy
  object_lock_enabled = false
}

# Set access control of bucket to private
resource "aws_s3_bucket_acl" "s3_reddit_bucket_acl" {
  bucket = aws_s3_bucket.reddit_bucket.id
  acl    = "private"

  # Depends_on resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.reddit_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

# Block all public access (modern default)
resource "aws_s3_bucket_public_access_block" "s3_block_public_access" {
  bucket                  = aws_s3_bucket.reddit_bucket.id
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
}
