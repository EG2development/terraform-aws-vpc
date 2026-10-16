# The examples are real configurations. Each must plan against the mocked
# provider, so an example that stops working fails CI.

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

run "basic_example_plans" {
  command = plan

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = length(module.vpc.private_subnet_ids) == 2 && length(module.vpc.public_subnet_ids) == 2
    error_message = "The basic example creates two subnets per tier."
  }
}

run "complete_example_plans" {
  command = plan

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = length(module.vpc.private_subnet_ids) == 3
    error_message = "The complete example creates three private subnets."
  }
}
