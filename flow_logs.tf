# VPC flow logs to CloudWatch Logs: the network-layer record of which address
# talked to which, and whether it was accepted. Delivery uses an IAM role that
# only the flow-logs service in this account can assume, and that may write
# only to this log group.

data "aws_caller_identity" "current" {
  count = var.flow_logs_enabled ? 1 : 0
}

data "aws_partition" "current" {
  count = var.flow_logs_enabled ? 1 : 0
}

data "aws_region" "current" {
  count = var.flow_logs_enabled ? 1 : 0
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.flow_logs_enabled ? 1 : 0

  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_in_days
  kms_key_id        = var.flow_logs_kms_key_arn

  tags = merge({ Name = "${var.name}-flow-logs" }, var.tags)
}

resource "aws_iam_role" "flow_logs" {
  count = var.flow_logs_enabled ? 1 : 0

  name = "${var.name}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
        # Confused-deputy protection: only flow logs owned by this account may
        # use the role.
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current[0].account_id }
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current[0].partition}:ec2:${data.aws_region.current[0].region}:${data.aws_caller_identity.current[0].account_id}:vpc-flow-log/*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.flow_logs_enabled ? 1 : 0

  name = "deliver-flow-logs"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count = var.flow_logs_enabled ? 1 : 0

  vpc_id                   = aws_vpc.main.id
  traffic_type             = var.flow_logs_traffic_type
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  max_aggregation_interval = var.flow_logs_max_aggregation_interval

  tags = merge({ Name = "${var.name}-flow-log" }, var.tags)
}
