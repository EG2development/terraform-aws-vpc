# Design decisions

Why the module is shaped the way it is, and what it leaves out on purpose.

## One VPC, two tiers

Most services need a place for load balancers and a place for everything else. The
module creates exactly that and stops. Anything that depends on what runs inside the
VPC — security groups, endpoints, peering — is added by the caller, using the
outputs. A module that tried to anticipate all of it would need dozens of inputs and
would still not fit the next team.

## Public subnets do not hand out public IPs

"Public" here means "has a route to the internet gateway". It does not mean every
instance launched there is reachable from the internet. Load balancers and NAT
gateways get their addresses explicitly; an instance gets one only when its own
configuration asks. This closes the most common accidental exposure in AWS
networking.

## Three NAT modes, not per-zone zonal gateways

- `single` is the cheapest way to give private subnets egress, and the right choice
  for development and for workloads that tolerate a zone outage.
- `regional` uses AWS's regional NAT gateway, which runs in every zone that has
  private subnets. It gives the availability of one NAT gateway per zone without
  one route table per zone, so the module keeps a single private route table.
- `none` is for isolated VPCs that reach AWS services through endpoints only.

One zonal NAT gateway per zone, the traditional high-availability layout, is not
offered: the regional gateway gives the same availability with fewer resources and
fewer moving parts.

## Default routes are separate resources

Route tables with inline `route` blocks claim every route in the table, so a route
added elsewhere is removed on the next apply. The module manages its default
routes as `aws_route` resources instead, which lets callers add their own routes to
the same tables.

## Flow logs are on by default

Flow logs are the only record of which address talked to which. They are cheap
compared with the cost of not having them after an incident, so the module creates
them unless told not to. The delivery role can be assumed only by the flow-logs
service acting for the same account, and can write only to its own log group.

## The default security group is emptied

Every VPC has a default security group that, unless changed, lets its members talk
to each other and to anywhere. Nothing should use it, so the module removes its
rules. A resource attached to it by mistake then fails closed.

## Names and addresses are stable

Resource names inside the module are fixed (`main`, `public`, `private`) and every
derived name follows `<name>-<suffix>`. Callers who migrate from an in-repository
VPC module with the same names keep their resource addresses, and the
[reference](../reference/names-tags-and-iam.md) is the contract: changing any of
those names is a breaking change.

## Left out on purpose

| Not included | Why |
| --- | --- |
| IPv6 | Needs egress-only gateways, IPv6 routes and different security rules; a separate major feature when someone needs it |
| Network ACLs | Security groups are the primary control; custom NACLs add a second, stateless rule set that is easy to get wrong |
| VPC endpoints | Which ones are worth it depends on the workload; the [how-to](../how-to/add-routes-and-endpoints.md) shows how to add them |
| Database subnet groups | They belong to the database, not the network: pass `private_subnet_ids` to the database module |
| More than two tiers | Rarely needed; call the module once and add subnets next to it if you do |
