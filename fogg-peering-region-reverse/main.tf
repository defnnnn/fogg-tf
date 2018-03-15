provider "aws" {}

variable "this_vpc_sg" {}

variable "that_vpc_cidrs" {
  default = []
}

variable "peering_connection" {}

variable "allow_access" {
  default = 1
}

resource "aws_vpc_peering_connection_accepter" "peering" {
  vpc_peering_connection_id = "${var.peering_connection}"
  auto_accept               = true
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
}

resource "aws_security_group_rule" "ssh_into_everything" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${var.that_vpc_cidrs}"]
  security_group_id = "${var.this_vpc_sg}"
  count             = "${var.allow_access}"
}
