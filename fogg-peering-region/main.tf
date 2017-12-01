provider "aws" {}

variable "this_vpc_id" {}
variable "that_vpc_id" {}
variable "that_vpc_region" {}

data "aws_caller_identity" "current" {}

resource "null_resource" "aws_vpc_peering_connection_region" {
  provisioner "local-exec" {
    command = "aws ec2 create-vpc-peering-connection --peer-owner-id ${data.aws_caller_identity.current.account_id} --peer-vpc-id ${var.that_vpc_id} --peer-region ${var.that_vpc_region} --vpc-id ${var.this_vpc_id}"
  }
}
