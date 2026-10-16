# How to add routes and endpoints

The module manages each route table's default route as a separate `aws_route`
resource, so you can add routes and endpoints to the same tables without Terraform
fighting over them. Add them in your own configuration, next to the module call.

## Add an S3 or DynamoDB gateway endpoint

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}
```

## Add a route to a peered VPC or a transit gateway

```hcl
resource "aws_route" "to_shared_services" {
  for_each = toset(module.vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "10.100.0.0/16"
  transit_gateway_id     = var.transit_gateway_id
}
```

Do not add a `0.0.0.0/0` route to a table the module manages: the module already
owns it, and two resources for the same destination fail at apply time.

## Allow the whole VPC in a security group

```hcl
resource "aws_vpc_security_group_ingress_rule" "from_vpc" {
  security_group_id = aws_security_group.service.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
```
