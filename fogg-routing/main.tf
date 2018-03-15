provider "aws" {}

variable "this_vpc_id" {}
variable "that_vpc_id" {}
variable "route_table_id" {}

data "aws_route_table" "rt" {
  route_table_id = "${var.route_table_id}"
}

data "aws_vpc_peering_connection" "peering" {
  vpc_id      = "${var.this_vpc_id}"
  peer_vpc_id = "${var.that_vpc_id}"
}

resource "aws_route" "rt" {
  route_table_id            = "${data.aws_route_table.rt.id}"
  destination_cidr_block    = "${aws_vpc_peering_connection.peering.peer_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.peering.id}"
}
