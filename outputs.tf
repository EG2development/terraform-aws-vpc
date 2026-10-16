output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "IPv4 CIDR block of the VPC, for security group rules that admit the whole VPC."
  value       = aws_vpc.main.cidr_block
}

output "availability_zones" {
  description = "Availability Zones the subnets use, in subnet order."
  value       = slice(local.availability_zones, 0, max(local.public_count, local.private_count))
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in the order of public_subnet_cidrs. Put load balancers here."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, in the order of private_subnet_cidrs. Put workloads and databases here."
  value       = aws_subnet.private[*].id
}

output "public_route_table_ids" {
  description = "IDs of the public route tables (zero or one today; a list so that per-zone tables can be added without changing the type)."
  value       = aws_route_table.public[*].id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables, for gateway endpoints and extra routes (zero or one today; a list for the same reason)."
  value       = aws_route_table.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway, or null when there is none."
  value       = one(aws_internet_gateway.main[*].id)
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway, or null when nat_gateway_mode is \"none\"."
  value       = one(aws_nat_gateway.main[*].id)
}

output "nat_public_ip" {
  description = "Elastic IP address of the single NAT gateway, for allow-lists at third parties. Null in the other modes (a regional NAT gateway allocates its addresses itself)."
  value       = one(aws_eip.nat[*].public_ip)
}

output "default_security_group_id" {
  description = "ID of the VPC's default security group (rules removed when manage_default_security_group is true)."
  value       = aws_vpc.main.default_security_group_id
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch log group that receives the flow logs, or null when flow logs are off."
  value       = one(aws_cloudwatch_log_group.flow_logs[*].name)
}
