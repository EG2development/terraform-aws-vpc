variable "name" {
  description = "Prefix for every name and Name tag the module creates, for example \"payments-prod\". The VPC is tagged \"{name}-vpc\"; docs/reference/names-tags-and-iam.md lists every derived name."
  type        = string
  nullable    = false

  validation {
    # The longest derived name is the flow-log IAM role "<name>-vpc-flow-logs",
    # and IAM role names are limited to 64 characters.
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,47}$", var.name))
    error_message = "name must be 1-48 characters: letters, digits and hyphens, starting with a letter or digit."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR block of the VPC, for example \"10.0.0.0/16\". Changing it replaces the VPC and everything in it."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && can(regex("^[0-9.]+/(1[6-9]|2[0-8])$", var.cidr_block))
    error_message = "cidr_block must be an IPv4 CIDR block with a prefix length between /16 and /28 (the range AWS allows for a VPC)."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets, one per Availability Zone in order. Public subnets route to an internet gateway but do not assign public IPs to instances. Empty creates no public subnet, no internet gateway (unless nat_gateway_mode is \"regional\") and no public route table."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry of public_subnet_cidrs must be an IPv4 CIDR block, for example \"10.0.1.0/24\"."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) == length(distinct(var.public_subnet_cidrs))
    error_message = "public_subnet_cidrs must not contain duplicates."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets, one per Availability Zone in order. Private subnets reach the internet only through the NAT gateway, when there is one."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry of private_subnet_cidrs must be an IPv4 CIDR block, for example \"10.0.10.0/24\"."
  }

  validation {
    condition     = length(var.private_subnet_cidrs) == length(distinct(var.private_subnet_cidrs))
    error_message = "private_subnet_cidrs must not contain duplicates."
  }
}

variable "availability_zones" {
  description = "Availability Zones for the subnets, in order: subnet N of each tier is placed in zone N. Null (default) uses the Region's zones that need no opt-in, sorted by name; pin the list in production so the choice is explicit."
  type        = list(string)
  default     = null

  validation {
    condition = var.availability_zones == null ? true : (
      length(var.availability_zones) >= max(length(var.public_subnet_cidrs), length(var.private_subnet_cidrs)) &&
      length(var.availability_zones) == length(distinct(var.availability_zones))
    )
    error_message = "availability_zones must list distinct zones, at least as many as the longer of public_subnet_cidrs and private_subnet_cidrs."
  }
}

variable "nat_gateway_mode" {
  description = "Outbound internet access for private subnets. \"single\" (default): one zonal NAT gateway with an Elastic IP in the first public subnet; cheapest, but private subnets lose egress if that zone fails. \"regional\": one regional NAT gateway that AWS expands into every zone with private subnets; highly available. \"none\": no NAT gateway and no default route from private subnets."
  type        = string
  default     = "single"
  nullable    = false

  validation {
    condition     = contains(["single", "regional", "none"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be \"single\", \"regional\" or \"none\"."
  }

  validation {
    condition     = var.nat_gateway_mode != "single" || length(var.public_subnet_cidrs) > 0
    error_message = "nat_gateway_mode \"single\" places the NAT gateway in a public subnet: set public_subnet_cidrs, or use \"regional\" or \"none\"."
  }
}

variable "flow_logs_enabled" {
  description = "Record VPC flow logs to a CloudWatch log group the module creates. On by default: without them, which address talked to which after an incident cannot be answered."
  type        = bool
  default     = true
  nullable    = false
}

variable "flow_logs_traffic_type" {
  description = "Traffic recorded by the flow log: ALL (default), ACCEPT or REJECT."
  type        = string
  default     = "ALL"
  nullable    = false

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be ALL, ACCEPT or REJECT."
  }
}

variable "flow_logs_max_aggregation_interval" {
  description = "Seconds over which a flow-log record aggregates packets: 60 (default, finer detail) or 600 (fewer records, lower cost)."
  type        = number
  default     = 60
  nullable    = false

  validation {
    condition     = contains([60, 600], var.flow_logs_max_aggregation_interval)
    error_message = "flow_logs_max_aggregation_interval must be 60 or 600."
  }
}

variable "flow_logs_retention_in_days" {
  description = "Days CloudWatch keeps flow-log records. Default 365."
  type        = number
  default     = 365
  nullable    = false

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_in_days)
    error_message = "flow_logs_retention_in_days must be a retention period CloudWatch Logs accepts, for example 90, 365 or 731."
  }
}

variable "flow_logs_kms_key_arn" {
  description = "ARN of a customer managed KMS key to encrypt the flow-log group. Null (default) uses CloudWatch Logs' own encryption. The key policy must allow the CloudWatch Logs service principal of this Region to use the key."
  type        = string
  default     = null
}

variable "manage_default_security_group" {
  description = "Take over the VPC's default security group and remove all of its rules, so anything accidentally attached to it gets no access. On by default. Turn it off only while adopting a VPC whose default group is still in use."
  type        = bool
  default     = true
  nullable    = false
}

variable "public_subnet_tags" {
  description = "Extra tags for the public subnets only, for example the tags a load-balancer controller uses to discover subnets."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "private_subnet_tags" {
  description = "Extra tags for the private subnets only."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "tags" {
  description = "Tags for every resource. The module adds a Name tag to each resource; a Name key here overrides it everywhere, so it is rarely what you want. Tags from the provider's default_tags apply as usual."
  type        = map(string)
  default     = {}
  nullable    = false
}
