# Resource names are "main" (and "public"/"private" per tier) so that a caller
# migrating from an in-repository VPC module with the same names keeps its
# addresses. Renaming one is a breaking change and needs a moved block.

locals {
  public_count  = length(var.public_subnet_cidrs)
  private_count = length(var.private_subnet_cidrs)

  availability_zones = var.availability_zones != null ? var.availability_zones : data.aws_availability_zones.available[0].names

  # A regional NAT gateway needs an internet gateway but no public subnet.
  create_internet_gateway = local.public_count > 0 || var.nat_gateway_mode == "regional"
  create_nat_gateway      = var.nat_gateway_mode != "none"
}

data "aws_availability_zones" "available" {
  count = var.availability_zones == null ? 1 : 0

  # Local Zones and Wavelength Zones need opt-in and offer a subset of
  # services; only the Region's ordinary zones are used by default. There is
  # deliberately no state filter: a zone that is temporarily impaired must not
  # drop out of the list, or every later subnet would move zone and be replaced.
  # The provider sorts names, and a new zone sorts after the existing ones.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

  lifecycle {
    postcondition {
      condition     = length(self.names) >= max(local.public_count, local.private_count)
      error_message = "The Region has fewer available Availability Zones than subnets per tier. Supply fewer subnet CIDRs or set availability_zones."
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge({ Name = "${var.name}-vpc" }, var.tags)
}

# Removes every rule from the default security group, so a resource attached to
# it by mistake has no network access. Destroying this resource only stops
# Terraform managing the group; AWS does not delete a default security group.
resource "aws_default_security_group" "main" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge({ Name = "${var.name}-default-deny" }, var.tags)
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = local.public_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]

  # Public means "routes to the internet gateway". Instances still get a public
  # address only when they ask for one, never by default.
  map_public_ip_on_launch = false

  tags = merge({ Name = "${var.name}-public-${count.index + 1}", Tier = "public" }, var.tags, var.public_subnet_tags)
}

resource "aws_subnet" "private" {
  count = local.private_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge({ Name = "${var.name}-private-${count.index + 1}", Tier = "private" }, var.tags, var.private_subnet_tags)
}

# ---------------------------------------------------------------------------
# Internet and NAT gateways
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  count = local.create_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge({ Name = "${var.name}-igw" }, var.tags)
}

resource "aws_eip" "nat" {
  count = var.nat_gateway_mode == "single" ? 1 : 0

  domain = "vpc"

  tags = merge({ Name = "${var.name}-nat-eip" }, var.tags)

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = local.create_nat_gateway ? 1 : 0

  # Set only for the regional mode, so a zonal gateway's configuration is the
  # same as on providers before regional NAT gateways existed.
  availability_mode = var.nat_gateway_mode == "regional" ? "regional" : null
  vpc_id            = var.nat_gateway_mode == "regional" ? aws_vpc.main.id : null

  allocation_id = var.nat_gateway_mode == "single" ? aws_eip.nat[0].id : null
  subnet_id     = var.nat_gateway_mode == "single" ? aws_subnet.public[0].id : null

  tags = merge({ Name = "${var.name}-nat" }, var.tags)

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------
# Routing. Default routes are separate aws_route resources, never inline
# blocks, so callers can add their own routes (peering, transit gateway,
# endpoints) to these tables without Terraform fighting over them.
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  count = local.public_count > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge({ Name = "${var.name}-public-rt" }, var.tags)
}

resource "aws_route" "public_internet" {
  count = local.public_count > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

resource "aws_route_table_association" "public" {
  count = local.public_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# One private route table for all zones: with a single or a regional NAT
# gateway every zone uses the same default route.
resource "aws_route_table" "private" {
  count = local.private_count > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge({ Name = "${var.name}-private-rt" }, var.tags)
}

resource "aws_route" "private_nat" {
  count = local.private_count > 0 && local.create_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "private" {
  count = local.private_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}
