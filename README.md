# terraform-aws-vpc

A Terraform module for one IPv4 VPC with public and private subnets across
Availability Zones, an internet gateway, a NAT gateway (single, regional or none),
VPC flow logs to CloudWatch Logs, and a locked-down default security group.

Use it when you need a conventional two-tier network: load balancers in public
subnets, workloads and databases in private subnets. You do not need to know
anything about the project it came from.

It deliberately does **not** manage:

- **What runs in the VPC.** Security groups for your workloads, VPC endpoints,
  peering, transit gateway attachments and extra routes belong next to the module
  call. The route-table outputs exist so you can add them.
- **IPv6, network ACLs and per-zone zonal NAT gateways.** See
  [design decisions](docs/explanation/design-decisions.md) for why.
- **Provider configuration and state.** There is no `provider` or `backend` block.

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/EG2development/terraform-aws-vpc.git?ref=v1.0.0" # x-release-please-version

  name                 = "payments-prod"
  cidr_block           = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}
```

Pin `?ref=`
to a release tag (inside the organisation) or the release's full commit SHA (outside
it), never to a branch. Run `terraform init` after changing `source`.

## Examples

| Example | Shows |
| --- | --- |
| [`examples/basic`](examples/basic) | Two zones, single NAT gateway, flow logs on |
| [`examples/complete`](examples/complete) | Three zones, regional NAT gateway, flow logs encrypted with a customer managed key, subnet tags for a load-balancer controller, an S3 gateway endpoint added with the route-table outputs |

## Documentation

| You want to | Read |
| --- | --- |
| Create your first VPC with this module | [Tutorial: deploy your first VPC](docs/tutorials/deploy-your-first-vpc.md) |
| Remove the single-zone NAT dependency | [How to make NAT highly available](docs/how-to/make-nat-highly-available.md) |
| Add endpoints, peering or transit gateway routes | [How to add routes and endpoints](docs/how-to/add-routes-and-endpoints.md) |
| Look up every name, tag and IAM permission the module creates | [Reference: names, tags and IAM](docs/reference/names-tags-and-iam.md) |
| See the resources and how they connect, on one page | [Architecture diagram](docs/reference/architecture.png) |
| Understand why it is built this way | [Design decisions](docs/explanation/design-decisions.md) |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9.0 |
| aws | >= 6.24 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.24 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| cidr\_block | IPv4 CIDR block of the VPC, for example "10.0.0.0/16". Changing it replaces the VPC and everything in it. | `string` | n/a | yes |
| name | Prefix for every name and Name tag the module creates, for example "payments-prod". The VPC is tagged "{name}-vpc"; docs/reference/names-tags-and-iam.md lists every derived name. | `string` | n/a | yes |
| availability\_zones | Availability Zones for the subnets, in order: subnet N of each tier is placed in zone N. Null (default) uses the Region's zones that need no opt-in, sorted by name; pin the list in production so the choice is explicit. | `list(string)` | `null` | no |
| flow\_logs\_enabled | Record VPC flow logs to a CloudWatch log group the module creates. On by default: without them, which address talked to which after an incident cannot be answered. | `bool` | `true` | no |
| flow\_logs\_kms\_key\_arn | ARN of a customer managed KMS key to encrypt the flow-log group. Null (default) uses CloudWatch Logs' own encryption. The key policy must allow the CloudWatch Logs service principal of this Region to use the key. | `string` | `null` | no |
| flow\_logs\_max\_aggregation\_interval | Seconds over which a flow-log record aggregates packets: 60 (default, finer detail) or 600 (fewer records, lower cost). | `number` | `60` | no |
| flow\_logs\_retention\_in\_days | Days CloudWatch keeps flow-log records. Default 365. | `number` | `365` | no |
| flow\_logs\_traffic\_type | Traffic recorded by the flow log: ALL (default), ACCEPT or REJECT. | `string` | `"ALL"` | no |
| manage\_default\_security\_group | Take over the VPC's default security group and remove all of its rules, so anything accidentally attached to it gets no access. On by default. Turn it off only while adopting a VPC whose default group is still in use. | `bool` | `true` | no |
| nat\_gateway\_mode | Outbound internet access for private subnets. "single" (default): one zonal NAT gateway with an Elastic IP in the first public subnet; cheapest, but private subnets lose egress if that zone fails. "regional": one regional NAT gateway that AWS expands into every zone with private subnets; highly available. "none": no NAT gateway and no default route from private subnets. | `string` | `"single"` | no |
| private\_subnet\_cidrs | CIDR blocks of the private subnets, one per Availability Zone in order. Private subnets reach the internet only through the NAT gateway, when there is one. | `list(string)` | `[]` | no |
| private\_subnet\_tags | Extra tags for the private subnets only. | `map(string)` | `{}` | no |
| public\_subnet\_cidrs | CIDR blocks of the public subnets, one per Availability Zone in order. Public subnets route to an internet gateway but do not assign public IPs to instances. Empty creates no public subnet, no internet gateway (unless nat\_gateway\_mode is "regional") and no public route table. | `list(string)` | `[]` | no |
| public\_subnet\_tags | Extra tags for the public subnets only, for example the tags a load-balancer controller uses to discover subnets. | `map(string)` | `{}` | no |
| tags | Tags for every resource. The module adds a Name tag to each resource; a Name key here overrides it everywhere, so it is rarely what you want. Tags from the provider's default\_tags apply as usual. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| availability\_zones | Availability Zones the subnets use, in subnet order. |
| default\_security\_group\_id | ID of the VPC's default security group (rules removed when manage\_default\_security\_group is true). |
| flow\_log\_group\_name | Name of the CloudWatch log group that receives the flow logs, or null when flow logs are off. |
| internet\_gateway\_id | ID of the internet gateway, or null when there is none. |
| nat\_gateway\_id | ID of the NAT gateway, or null when nat\_gateway\_mode is "none". |
| nat\_public\_ip | Elastic IP address of the single NAT gateway, for allow-lists at third parties. Null in the other modes (a regional NAT gateway allocates its addresses itself). |
| private\_route\_table\_ids | IDs of the private route tables, for gateway endpoints and extra routes (zero or one today; a list for the same reason). |
| private\_subnet\_ids | IDs of the private subnets, in the order of private\_subnet\_cidrs. Put workloads and databases here. |
| public\_route\_table\_ids | IDs of the public route tables (zero or one today; a list so that per-zone tables can be added without changing the type). |
| public\_subnet\_ids | IDs of the public subnets, in the order of public\_subnet\_cidrs. Put load balancers here. |
| vpc\_arn | ARN of the VPC. |
| vpc\_cidr\_block | IPv4 CIDR block of the VPC, for security group rules that admit the whole VPC. |
| vpc\_id | ID of the VPC. |
<!-- END_TF_DOCS -->

## Defaults and security decisions

| Decision | Default | Why | How to change it |
| --- | --- | --- | --- |
| Public IPs on launch | Off in public subnets | An instance is reachable from the internet only when it asks for an address | Ask for one on the instance (`associate_public_ip_address`) |
| Flow logs | On: ALL traffic, 60-second aggregation, 365-day retention | Answers "what talked to what" after an incident | `flow_logs_enabled`, `flow_logs_traffic_type`, `flow_logs_max_aggregation_interval`, `flow_logs_retention_in_days` |
| Flow-log encryption | CloudWatch Logs' own encryption | Nothing to manage | `flow_logs_kms_key_arn` |
| Flow-log delivery role | Trusts only `vpc-flow-logs.amazonaws.com` acting for this account; may only write to its own log group | Least privilege and confused-deputy protection | Not configurable |
| Default security group | All rules removed | A resource attached to it by mistake gets no access | `manage_default_security_group = false` |
| NAT gateway | `single` | Cheapest working egress | `nat_gateway_mode = "regional"` for high availability, `"none"` for no egress |
| Availability Zones | The Region's zones that need no opt-in, by name | Excludes Local and Wavelength Zones | `availability_zones` |

## Security scanning

Checkov runs on every pull request. Two checks are skipped, in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml):

| Check | Why it is skipped |
| --- | --- |
| `CKV2_AWS_19` "EIP attached to an EC2 instance" | False positive: the Elastic IP is attached to the NAT gateway, which is what it is for |
| `CKV_AWS_394` "availability zones data source pins zone identity" | The lookup runs only when `availability_zones` is null. Its result is sorted by name and the module uses the first N zones, so a zone AWS adds later sorts after the ones in use and moves no subnet. Callers who want the list pinned set `availability_zones` |

## Upgrading

Read [`CHANGELOG.md`](CHANGELOG.md) for every version between yours and the new one,
change `?ref=`, run `terraform init`, and review the plan. A minor or patch release
plans no changes unless you opt into something new. Changing `nat_gateway_mode`
replaces the NAT gateway and interrupts egress for a few minutes; see the
[how-to](docs/how-to/make-nat-highly-available.md).

## Versioning and releases

Semantic versions, tags `vMAJOR.MINOR.PATCH`, created by release-please from
Conventional Commit pull-request titles. Patch: a fix that changes no plan. Minor: a
new optional input, output or off-by-default resource. Major: anything that can
change or replace an existing caller's resources, or raise a minimum version.
Details: [the standard](https://github.com/EG2development/terraform-module-standards/blob/main/docs/standard.md).

## Contributing and ownership

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The team in
[`.github/CODEOWNERS`](.github/CODEOWNERS) reviews every change and owns releases.
Report vulnerabilities as described in [`SECURITY.md`](SECURITY.md).
