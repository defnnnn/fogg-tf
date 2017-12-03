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
  default = 0
}

data "aws_caller_identity" "current" {}

resource "null_resource" "aws_vpc_peering_connection_region" {
  provisioner "local-exec" {
    command = "aws ${var.this_vpc_region} ec2 create-vpc-peering-connection --peer-owner-id ${data.aws_caller_identity.current.account_id} --peer-vpc-id ${var.that_vpc_id} --peer-region ${var.that_vpc_region} --vpc-id ${var.this_vpc_id}"
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
