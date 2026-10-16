variable "region" {
  description = "AWS Region to create the VPC in."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name prefix for the VPC and everything in it."
  type        = string
  default     = "example"
}
