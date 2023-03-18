variable "vpc_cidr" {
  type = string
}

## Create VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
}

## Internet Gateway is the logical connection between a VPC and the internet.
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
}

## Elastic IP for NAT
resource "aws_eip" "nat" {
  count         = lookup(null_resource.zone_count.triggers, "total")
  vpc           = true
  depends_on    = [aws_internet_gateway.ig]
}

/*
NAT Gateway is used by instances in a private subnet to have a one-way traffic flow to outside the VPC,
but external services cannot instantiate a connection with the private instances.

NAT Gateways are created per AZ, so a multi-AZ infra will have a NAT Gateway per AZ.
*/
resource "aws_nat_gateway" "nat" {
  count           = lookup(null_resource.zone_count.triggers, "total")
  allocation_id   = element(aws_eip.nat.*.id, count.index)
  subnet_id       = element(aws_subnet.public.*.id, count.index)
}

/*
Configure public subnets by defining route table entries to the IG, per AZ.
*/

## Create a public subnet
resource "aws_subnet" "public" {
  count                     = lookup(null_resource.zone_count.triggers, "total")
  availability_zone         = data.aws_availability_zones.available.names[count.index]
  cidr_block                = "${cidrsubnet(aws_vpc.vpc.cidr_block, 3, count.index)}"
  map_public_ip_on_launch   = true
  vpc_id                    = aws_vpc.vpc.id
}

## Create a route table for public traffic
resource "aws_route_table" "public" {
  count     = lookup(null_resource.zone_count.triggers, "total")
  vpc_id    = aws_vpc.vpc.id
}

## Create a routing entry in the public route table directing traffic to IG
resource "aws_route" "public" {
  count                     = lookup(null_resource.zone_count.triggers, "total")
  route_table_id            = element(aws_route_table.public.*.id, count.index)
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.ig.id
}

## Create an association between the public route table and the public subnet
resource "aws_route_table_association" "public" {
  count             = lookup(null_resource.zone_count.triggers, "total")
  route_table_id    = element(aws_route_table.public.*.id, count.index)
  subnet_id         = element(aws_subnet.public.*.id, count.index)
}

/*
Configure private subnets by defining route table entries to the NAT, per AZ.
*/

## Create a private subnet
resource "aws_subnet" "private" {
  count                     = lookup(null_resource.zone_count.triggers, "total")
  availability_zone         = data.aws_availability_zones.available.names[count.index]
  cidr_block                = "${cidrsubnet(aws_vpc.vpc.cidr_block, 3, count.index + 4)}"
  map_public_ip_on_launch   = false
  vpc_id                    = aws_vpc.vpc.id
}

## Create a route table for private traffic
resource "aws_route_table" "private" {
  count     = lookup(null_resource.zone_count.triggers, "total")
  vpc_id    = aws_vpc.vpc.id
}

## Create an routing entry in the private route table directing traffic to the NAT Gateway
resource "aws_route" "private" {
  count                   = lookup(null_resource.zone_count.triggers, "total")
  route_table_id          = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block  = "0.0.0.0/0"
  nat_gateway_id          = element(aws_nat_gateway.nat.*.id, count.index)
}

## Create an association between the private route table and the private subnet
resource "aws_route_table_association" "private" {
  count               = lookup(null_resource.zone_count.triggers, "total")
  route_table_id      = element(aws_route_table.private.*.id, count.index)
  subnet_id           = element(aws_subnet.private.*.id, count.index)
}

