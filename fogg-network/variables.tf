variable "network_name" {}

variable "vpc_id" {}
variable "env_name" {}

variable "env_sg" {}

variable "subnets" {
  default = []
}

variable "want_eip" {
  default = 1
}

variable "interface_count" {
  default = 0
}

output "network_sg" {
  value = "${aws_security_group.network.id}"
}

output "interfaces" {
  value = ["${aws_network_interface.network.*.id}"]
}

output "allocation_id" {
  value = ["${aws_eip.network.*.id}"]
}

output "eips" {
  value = ["${aws_eip.network.*.public_ip}"]
}
