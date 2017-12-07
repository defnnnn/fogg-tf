variable "region" {}
variable "command" {}

variable "resource_type" {
  default = "_"
}

variable "resource_previous" {}
variable "resource_name" {}

variable "arg1" {
  default = ""
}

variable "arg2" {
  default = ""
}

variable "arg3" {
  default = ""
}

variable "arg4" {
  default = ""
}

variable "mcount" {
  default = 1
}

variable "anchor" {
  default = ""
}

locals {
  arg1         = "${var.arg1}"
  arg2         = "${var.arg2}"
  arg3         = "${var.arg3}"
  arg4         = "${var.arg4}"
  out1         = "${lookup(data.external.lookup.result,"out1")}"
  out2         = "${lookup(data.external.lookup.result,"out2")}"
  out3         = "${lookup(data.external.lookup.result,"out3")}"
  out4         = "${lookup(data.external.lookup.result,"out4")}"
  prev1        = "${lookup(data.external.previous.result,"out1")}"
  prev2        = "${lookup(data.external.previous.result,"out2")}"
  prev3        = "${lookup(data.external.previous.result,"out3")}"
  prev4        = "${lookup(data.external.previous.result,"out4")}"
  command_args = "'${var.resource_name}' '${local.arg1}' '${local.arg2}' '${local.arg3}' '${local.arg4}' '${local.out1}' '${local.out2}' '${local.out3}' '${local.out4}' '${local.prev1}' '${local.prev2}' '${local.prev3}' '${local.prev4}'"
}

data "external" "previous" {
  program = ["${var.command}", "${var.region}", "${var.resource_type}", "lookup", "${var.resource_previous}", "_${local.arg1}", "_${local.arg2}", "_${local.arg3}", "_${local.arg4}"]
}

data "external" "lookup" {
  program = ["${var.command}", "${var.region}", "${var.resource_type}", "lookup", "${var.resource_name}", "_${local.arg1}", "_${local.arg2}", "_${local.arg3}", "_${local.arg4}"]
}

resource "random_string" "recreate" {
  length = 8
}

resource "null_resource" "resource" {
  triggers {
    recreate      = "${random_string.recreate.id}"
    resource_name = "${var.resource_name}"
    arg1          = "${local.arg1}"
    arg2          = "${local.arg2}"
    arg3          = "${local.arg3}"
    arg4          = "${local.arg4}"
    anchor        = "${var.anchor}"
  }

  provisioner "local-exec" {
    command = "${var.command} ${var.region} ${var.resource_type} create ${local.command_args}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "${var.command} ${var.region} ${var.resource_type} destroy ${local.command_args}"
  }

  count = "${var.mcount}"
}

output "resource_type" {
  value = "${var.resource_type}"
}

output "resource_name" {
  value = "${var.resource_name}"
}

output "arg1" {
  value = "${local.arg1}"
}

output "arg2" {
  value = "${local.arg2}"
}

output "arg3" {
  value = "${local.arg3}"
}

output "arg4" {
  value = "${local.arg4}"
}

output "out1" {
  value = "${local.out1}"
}

output "out2" {
  value = "${local.out2}"
}

output "out3" {
  value = "${local.out3}"
}

output "out4" {
  value = "${local.out4}"
}

output "id" {
  value = "${random_string.recreate.id}"
}
