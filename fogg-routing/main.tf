provider "aws" {}

variable "this_vpc_id" {}
variable "that_vpc_id" {}
variable "that_vpc_cidr" {}
variable "route_table_id" {}

locals {
  vpc_ids      = "${sort(list(var.this_vpc_id,var.that_vpc_id))}"
  peering_name = "${local.vpc_ids[0]}_${local.vpc_ids[1]}"
}

data "aws_route_table" "rt" {
  route_table_id = "${var.route_table_id}"
}

data "aws_vpc_peering_connection" "peering" {
  status = "active"

  tags {
    Name = "${local.peering_name}"
  }
}

resource "aws_route" "rt" {
  route_table_id            = "${data.aws_route_table.rt.id}"
  destination_cidr_block    = "${var.that_vpc_cidr}"
  vpc_peering_connection_id = "${data.aws_vpc_peering_connection.peering.id}"
}
