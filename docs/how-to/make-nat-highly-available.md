# How to make NAT highly available

With the default `nat_gateway_mode = "single"`, every private subnet sends its
internet traffic through one NAT gateway in the first public subnet. If that zone
fails, private subnets in the other zones lose outbound access. A regional NAT
gateway removes that dependency: AWS runs it in every zone that has private subnets.

## For a new VPC

Set the mode when you first create the VPC:

```hcl
module "vpc" {
  # ...
  nat_gateway_mode = "regional"
}
```

## For an existing VPC

Changing the mode replaces the NAT gateway. Outbound connections from private
subnets drop and new ones fail until the new gateway is available, usually a few
minutes. Plan it into a maintenance window.

1. Set `nat_gateway_mode = "regional"` and run `terraform plan`.
2. Check the plan contains exactly these changes, and nothing else:
   - `aws_nat_gateway.main[0]` must be replaced,
   - `aws_eip.nat[0]` will be destroyed,
   - `aws_route.private_nat[0]` will be updated in place or replaced.
3. Tell anyone who allow-lists the old NAT address (`nat_public_ip` output) that
   it is going away. A regional NAT gateway allocates its own addresses; find them
   in the EC2 console or with
   `aws ec2 describe-nat-gateways --nat-gateway-ids "$(terraform output -raw nat_gateway_id)"`.
4. Run `terraform apply` in the maintenance window.

To go back, set `nat_gateway_mode = "single"` and apply; the same interruption
applies, and the new Elastic IP has a different address.
