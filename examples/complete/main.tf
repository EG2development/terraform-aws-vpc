# A production-style VPC: three zones, a regional NAT gateway (no single-zone
# egress failure), flow logs encrypted with a customer managed key and kept for
# two years, subnet tags for a load-balancer controller, and an S3 gateway
# endpoint added next to the module using its route-table outputs.

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

module "vpc" {
  source = "../.."

  name                 = var.name
  cidr_block           = "10.20.0.0/16"
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = ["10.20.16.0/20", "10.20.32.0/20", "10.20.48.0/20"]

  nat_gateway_mode = "regional"

  flow_logs_retention_in_days = 731
  flow_logs_kms_key_arn       = aws_kms_key.flow_logs.arn

  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

  tags = {
    Environment = "prod"
    Team        = "platform"
  }
}

# Customer managed key for the flow-log group. CloudWatch Logs may use it only
# for log groups in this account and Region.
resource "aws_kms_key" "flow_logs" {
  description         = "${var.name} VPC flow logs"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchLogsInThisAccount"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
    ]
  })
}

# Composition: S3 traffic from private subnets stays on the AWS network and
# does not pay NAT data processing.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = { Name = "${var.name}-s3" }
}
