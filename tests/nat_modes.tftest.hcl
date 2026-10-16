# The three NAT gateway modes.

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

run "regional_nat_gateway" {
  command = apply

  variables {
    nat_gateway_mode = "regional"
  }

  assert {
    condition     = aws_nat_gateway.main[0].availability_mode == "regional" && aws_nat_gateway.main[0].vpc_id == aws_vpc.main.id
    error_message = "A regional NAT gateway is created in the VPC."
  }

  assert {
    condition     = aws_nat_gateway.main[0].subnet_id == null && aws_nat_gateway.main[0].allocation_id == null && length(aws_eip.nat) == 0
    error_message = "A regional NAT gateway takes no subnet and no module-managed Elastic IP."
  }

  assert {
    condition     = aws_route.private_nat[0].nat_gateway_id == aws_nat_gateway.main[0].id
    error_message = "Private subnets route through the regional NAT gateway."
  }
}

run "regional_nat_gateway_without_public_subnets" {
  command = plan

  variables {
    nat_gateway_mode    = "regional"
    public_subnet_cidrs = []
  }

  assert {
    condition     = length(aws_internet_gateway.main) == 1 && length(aws_route_table.public) == 0 && length(aws_subnet.public) == 0
    error_message = "A regional NAT gateway needs an internet gateway even with no public subnet."
  }
}

run "no_nat_gateway" {
  command = plan

  variables {
    nat_gateway_mode = "none"
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 0 && length(aws_eip.nat) == 0 && length(aws_route.private_nat) == 0
    error_message = "nat_gateway_mode = \"none\" creates no NAT gateway, Elastic IP or private default route."
  }

  assert {
    condition     = length(aws_route_table.private) == 1 && length(aws_route_table_association.private) == 2
    error_message = "Private subnets still get their route table."
  }
}

run "private_only_vpc" {
  command = plan

  variables {
    nat_gateway_mode    = "none"
    public_subnet_cidrs = []
  }

  assert {
    condition     = length(aws_internet_gateway.main) == 0 && length(aws_route.public_internet) == 0
    error_message = "A VPC with no public subnets and no NAT gateway has no internet gateway."
  }
}
