# What a caller gets from the required inputs plus two tiers of subnets. These
# assertions pin names, tags and secure defaults; a change to any of them
# changes existing callers' infrastructure, which is a major release.
# The provider is mocked: no credentials, nothing created.

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
  tags                 = { Team = "platform" }
}

run "network_layout" {
  command = apply

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16" && aws_vpc.main.enable_dns_support && aws_vpc.main.enable_dns_hostnames
    error_message = "The VPC must use cidr_block with DNS support and hostnames on."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "One subnet per CIDR in each tier."
  }

  assert {
    condition     = [for s in aws_subnet.public : s.availability_zone] == ["eu-west-2a", "eu-west-2b"] && [for s in aws_subnet.private : s.availability_zone] == ["eu-west-2a", "eu-west-2b"]
    error_message = "Subnet N of each tier must be in the N-th available zone."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "Public subnets must not assign public IPs by default."
  }

  assert {
    condition     = aws_nat_gateway.main[0].subnet_id == aws_subnet.public[0].id && aws_nat_gateway.main[0].allocation_id == aws_eip.nat[0].id
    error_message = "The single NAT gateway must sit in the first public subnet with the module's Elastic IP."
  }

  assert {
    condition     = aws_route.public_internet[0].gateway_id == aws_internet_gateway.main[0].id && aws_route.public_internet[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "The public route table must send 0.0.0.0/0 to the internet gateway."
  }

  assert {
    condition     = aws_route.private_nat[0].nat_gateway_id == aws_nat_gateway.main[0].id && aws_route.private_nat[0].route_table_id == aws_route_table.private[0].id
    error_message = "The private route table must send 0.0.0.0/0 to the NAT gateway."
  }

  assert {
    condition     = alltrue([for a in aws_route_table_association.private : a.route_table_id == aws_route_table.private[0].id]) && length(aws_route_table_association.public) == 2
    error_message = "Every subnet must be associated with its tier's route table."
  }

  assert {
    condition     = length(aws_default_security_group.main) == 1
    error_message = "The default security group must be managed (all rules removed) by default."
  }
}

run "names_and_tags_are_stable" {
  command = plan

  # Callers that migrate from an in-repository module with the same naming
  # rely on these exact names; changing one is a breaking change.
  assert {
    condition     = aws_vpc.main.tags == tomap({ Name = "example-vpc", Team = "platform" })
    error_message = "VPC tags must be Name=<name>-vpc plus var.tags."
  }

  assert {
    condition     = aws_subnet.public[1].tags == tomap({ Name = "example-public-2", Tier = "public", Team = "platform" }) && aws_subnet.private[0].tags == tomap({ Name = "example-private-1", Tier = "private", Team = "platform" })
    error_message = "Subnet tags must be Name=<name>-<tier>-<n>, Tier=<tier>, plus var.tags."
  }

  assert {
    condition = (
      aws_internet_gateway.main[0].tags["Name"] == "example-igw" &&
      aws_eip.nat[0].tags["Name"] == "example-nat-eip" &&
      aws_nat_gateway.main[0].tags["Name"] == "example-nat" &&
      aws_route_table.public[0].tags["Name"] == "example-public-rt" &&
      aws_route_table.private[0].tags["Name"] == "example-private-rt"
    )
    error_message = "Gateway and route-table Name tags changed."
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.flow_logs[0].name == "/vpc/example/flow-logs" &&
      aws_cloudwatch_log_group.flow_logs[0].tags["Name"] == "example-flow-logs" &&
      aws_iam_role.flow_logs[0].name == "example-vpc-flow-logs" &&
      aws_iam_role.flow_logs[0].tags == tomap({ Team = "platform" }) &&
      aws_iam_role_policy.flow_logs[0].name == "deliver-flow-logs" &&
      aws_flow_log.main[0].tags["Name"] == "example-flow-log"
    )
    error_message = "Flow-log names or tags changed."
  }
}

run "flow_logs_are_on_and_least_privilege" {
  command = plan

  assert {
    condition = (
      aws_flow_log.main[0].traffic_type == "ALL" &&
      aws_flow_log.main[0].max_aggregation_interval == 60 &&
      aws_flow_log.main[0].log_destination_type == "cloud-watch-logs" &&
      aws_cloudwatch_log_group.flow_logs[0].retention_in_days == 365 &&
      aws_cloudwatch_log_group.flow_logs[0].kms_key_id == null
    )
    error_message = "Flow logs must record ALL traffic every 60 s into a log group kept for 365 days."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.flow_logs[0].assume_role_policy).Statement[0].Principal.Service == "vpc-flow-logs.amazonaws.com" &&
      jsondecode(aws_iam_role.flow_logs[0].assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "111122223333" &&
      jsondecode(aws_iam_role.flow_logs[0].assume_role_policy).Statement[0].Condition.ArnLike["aws:SourceArn"] == "arn:aws:ec2:eu-west-2:111122223333:vpc-flow-log/*"
    )
    error_message = "Only this account's flow logs may assume the delivery role (confused-deputy protection)."
  }

  assert {
    condition = (
      length(jsondecode(aws_iam_role_policy.flow_logs[0].policy).Statement) == 1 &&
      jsondecode(aws_iam_role_policy.flow_logs[0].policy).Statement[0].Action == ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
    )
    error_message = "The delivery role may only write log streams and events."
  }
}
