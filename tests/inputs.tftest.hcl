# Optional inputs change only what they say.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-west-2a", "eu-west-2b", "eu-west-2c"] }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-west-2" }
  }
  # The provider checks that these are ARNs, so the mock must return ARN-shaped values.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:eu-west-2:111122223333:log-group:/vpc/example/flow-logs" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111122223333:role/example-vpc-flow-logs" }
  }
}

variables {
  name                 = "example"
  cidr_block           = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

run "explicit_availability_zones_skip_the_lookup" {
  command = plan

  variables {
    availability_zones = ["eu-west-2c", "eu-west-2a"]
  }

  assert {
    condition     = length(data.aws_availability_zones.available) == 0
    error_message = "With availability_zones set, the module must not look zones up."
  }

  assert {
    condition     = aws_subnet.private[0].availability_zone == "eu-west-2c" && aws_subnet.public[1].availability_zone == "eu-west-2a"
    error_message = "Subnets must follow the order of availability_zones."
  }

  assert {
    condition     = output.availability_zones == tolist(["eu-west-2c", "eu-west-2a"])
    error_message = "The availability_zones output lists the zones in use."
  }
}

run "flow_logs_off" {
  command = plan

  variables {
    flow_logs_enabled = false
  }

  assert {
    condition = (
      length(aws_flow_log.main) == 0 && length(aws_cloudwatch_log_group.flow_logs) == 0 &&
      length(aws_iam_role.flow_logs) == 0 && length(aws_iam_role_policy.flow_logs) == 0 &&
      length(data.aws_caller_identity.current) == 0
    )
    error_message = "flow_logs_enabled = false must create no flow-log resources and make no lookups for them."
  }

  assert {
    condition     = output.flow_log_group_name == null
    error_message = "flow_log_group_name is null when flow logs are off."
  }
}

run "flow_log_settings" {
  command = plan

  variables {
    flow_logs_traffic_type             = "REJECT"
    flow_logs_max_aggregation_interval = 600
    flow_logs_retention_in_days        = 731
    flow_logs_kms_key_arn              = "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition = (
      aws_flow_log.main[0].traffic_type == "REJECT" &&
      aws_flow_log.main[0].max_aggregation_interval == 600 &&
      aws_cloudwatch_log_group.flow_logs[0].retention_in_days == 731 &&
      aws_cloudwatch_log_group.flow_logs[0].kms_key_id == "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000000"
    )
    error_message = "Flow-log inputs must reach the flow log and its log group."
  }
}

run "default_security_group_left_alone" {
  command = plan

  variables {
    manage_default_security_group = false
  }

  assert {
    condition     = length(aws_default_security_group.main) == 0
    error_message = "manage_default_security_group = false must not touch the default security group."
  }
}

run "tier_tags" {
  command = plan

  variables {
    tags                = { Team = "platform" }
    public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
    private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
  }

  assert {
    condition     = aws_subnet.public[0].tags["kubernetes.io/role/elb"] == "1" && !contains(keys(aws_subnet.private[0].tags), "kubernetes.io/role/elb")
    error_message = "public_subnet_tags apply to public subnets only."
  }

  assert {
    condition     = aws_subnet.private[1].tags["kubernetes.io/role/internal-elb"] == "1" && aws_subnet.private[1].tags["Team"] == "platform"
    error_message = "private_subnet_tags apply to private subnets, together with var.tags."
  }

  assert {
    condition     = !contains(keys(aws_vpc.main.tags), "kubernetes.io/role/elb")
    error_message = "Tier tags must not leak onto other resources."
  }
}
