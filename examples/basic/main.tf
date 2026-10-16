# The smallest useful call: two zones, a public and a private subnet in each,
# one NAT gateway, flow logs on. Examples call the module from the working copy
# so CI validates this repository's code; a real caller pins a Git source
# (README.md, "Usage").

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../.."

  name                 = var.name
  cidr_block           = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}
