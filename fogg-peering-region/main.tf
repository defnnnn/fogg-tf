provider "aws" {}

variable "this_vpc_sg" {}
variable "this_vpc_id" {}
variable "this_vpc_region" {}

variable "this_vpc_cidrs" {
  default = []
}

variable "that_vpc_sg" {}
variable "that_vpc_id" {}
variable "that_vpc_region" {}

variable "that_vpc_cidrs" {
  default = []
}

variable "allow_access" {
  default = 1
}

data "aws_caller_identity" "current" {}

resource "aws_vpc_peering_connection" "peering" {
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  peer_vpc_id   = "${var.that_vpc_id}"
  vpc_id        = "${var.this_vpc_id}"
  peer_region   = "${var.that_vpc_region}"

  tags {
    Name = "${var.this_vpc_id}_${var.that_vpc_id}"
  }
}

# let peers access
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

output "peering_connection" {
  value = "${aws_vpc_peering_connection.peering.id}"
}
