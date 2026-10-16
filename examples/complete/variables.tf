variable "region" {
  description = "AWS Region to create the VPC in."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name prefix for the VPC and everything in it."
  type        = string
  default     = "example-prod"
}

variable "availability_zones" {
  description = "Three Availability Zones in var.region."
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}
