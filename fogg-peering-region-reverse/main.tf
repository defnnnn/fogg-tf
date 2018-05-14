provider "aws" {}

variable "this_vpc_id" {}
variable "that_vpc_id" {}

variable "this_vpc_sg" {}

variable "that_vpc_cidrs" {
  default = []
}

variable "peering_connection" {}

variable "allow_access" {
  default = 1
}

locals {
  vpc_ids      = "${sort(list(var.this_vpc_id,var.that_vpc_id))}"
  peering_name = "${local.vpc_ids[0]}_${local.vpc_ids[1]}"
}

resource "aws_vpc_peering_connection_accepter" "peering" {
  vpc_peering_connection_id = "${var.peering_connection}"
  auto_accept               = true

  tags {
    Name = "${local.peering_name}"
  }
}

# access on the peer
resource "aws_security_group_rule" "ping_everything" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["${var.that_vpc_cidrs}"]
  security_group_id = "${var.this_vpc_sg}"
  count             = "${var.allow_access}"
  description       = "peer can ping us"
}

resource "aws_security_group_rule" "ssh_into_everything" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${var.that_vpc_cidrs}"]
  security_group_id = "${var.this_vpc_sg}"
  count             = "${var.allow_access}"
  description       = "peer can ssh to us"
}
