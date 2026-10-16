# Tutorial: deploy your first VPC

In this tutorial you create a VPC with two public and two private subnets, check
that it exists, and remove it again. It takes about ten minutes and costs a few
pence: the NAT gateway and its Elastic IP are billed by the hour.

## Before you start

- Terraform 1.9 or later, and credentials for a sandbox AWS account that may create
  VPCs, subnets, gateways, Elastic IPs, IAM roles and CloudWatch log groups.
- Read access to this repository (`git ls-remote https://github.com/EG2development/terraform-aws-vpc.git`
  lists its tags).

## 1. Write the configuration

Create an empty directory and a file `main.tf` in it:

```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.24"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

module "vpc" {
  source = "git::https://github.com/EG2development/terraform-aws-vpc.git?ref=v1.0.0"

  name                 = "tutorial"
  cidr_block           = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
```

## 2. Create the VPC

```bash
terraform init
terraform apply
```

Read the plan before you type `yes`. You should see about 25 resources: the VPC, four
subnets, an internet gateway, a NAT gateway with its Elastic IP, two route tables with
their routes and associations, the default security group, and the flow-log group,
role, policy and flow log.

## 3. Check what you built

```bash
VPC_ID="$(terraform output -raw vpc_id)"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output table
aws ec2 describe-flow-logs --filter "Name=resource-id,Values=${VPC_ID}" \
  --query 'FlowLogs[].[LogGroupName,TrafficType,FlowLogStatus]' --output table
```

You see `tutorial-public-1`, `tutorial-public-2`, `tutorial-private-1` and
`tutorial-private-2`, none of which assigns public IPs, and one flow log in the
`ACTIVE` state writing to `/vpc/tutorial/flow-logs`.

## 4. Clean up

```bash
terraform destroy
```

The flow-log group is deleted with everything else, and the records in it are lost.

## Next steps

- [Make NAT highly available](../how-to/make-nat-highly-available.md) before you put
  production workloads in the private subnets.
- [Add routes and endpoints](../how-to/add-routes-and-endpoints.md) for S3, peering or
  a transit gateway.
