# Every validation rejects bad input at plan time, before any API call.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-west-2a", "eu-west-2b"] }
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

run "accepts_valid_input" {
  command = plan
}

run "rejects_name_with_invalid_characters" {
  command = plan
  variables {
    name = "my_vpc"
  }
  expect_failures = [var.name]
}

run "rejects_name_too_long_for_iam" {
  command = plan
  variables {
    name = "a234567890123456789012345678901234567890123456789"
  }
  expect_failures = [var.name]
}

run "rejects_invalid_cidr_block" {
  command = plan
  variables {
    cidr_block = "10.0.0.0/33"
  }
  expect_failures = [var.cidr_block]
}

run "rejects_vpc_larger_than_slash_16" {
  command = plan
  variables {
    cidr_block = "10.0.0.0/8"
  }
  expect_failures = [var.cidr_block]
}

run "rejects_invalid_subnet_cidr" {
  command = plan
  variables {
    private_subnet_cidrs = ["10.0.10.0/24", "not-a-cidr"]
  }
  expect_failures = [var.private_subnet_cidrs]
}

run "rejects_duplicate_subnet_cidrs" {
  command = plan
  variables {
    public_subnet_cidrs = ["10.0.1.0/24", "10.0.1.0/24"]
  }
  expect_failures = [var.public_subnet_cidrs]
}

run "rejects_unknown_nat_gateway_mode" {
  command = plan
  variables {
    nat_gateway_mode = "per_az"
  }
  expect_failures = [var.nat_gateway_mode]
}

run "rejects_single_nat_gateway_without_public_subnets" {
  command = plan
  variables {
    public_subnet_cidrs = []
  }
  expect_failures = [var.nat_gateway_mode]
}

run "rejects_too_few_availability_zones" {
  command = plan
  variables {
    availability_zones = ["eu-west-2a"]
  }
  expect_failures = [var.availability_zones]
}

run "rejects_duplicate_availability_zones" {
  command = plan
  variables {
    availability_zones = ["eu-west-2a", "eu-west-2a"]
  }
  expect_failures = [var.availability_zones]
}

run "rejects_more_subnets_than_region_zones" {
  command = plan
  variables {
    private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  }
  expect_failures = [data.aws_availability_zones.available]
}

run "rejects_unsupported_retention" {
  command = plan
  variables {
    flow_logs_retention_in_days = 100
  }
  expect_failures = [var.flow_logs_retention_in_days]
}

run "rejects_unsupported_aggregation_interval" {
  command = plan
  variables {
    flow_logs_max_aggregation_interval = 300
  }
  expect_failures = [var.flow_logs_max_aggregation_interval]
}

run "rejects_unknown_traffic_type" {
  command = plan
  variables {
    flow_logs_traffic_type = "SOME"
  }
  expect_failures = [var.flow_logs_traffic_type]
}
