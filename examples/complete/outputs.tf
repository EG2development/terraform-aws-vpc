output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs, one per zone."
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
  description = "ID of the regional NAT gateway."
  value       = module.vpc.nat_gateway_id
}

output "flow_log_group_name" {
  description = "CloudWatch log group holding the flow logs."
  value       = module.vpc.flow_log_group_name
}
