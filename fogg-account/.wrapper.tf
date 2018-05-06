variable "remote_bucket" {}
variable "remote_region" {}

variable "logical_name" {}
variable "name" {}
variable "email" {}
variable "role_name" {}

module "account" {
  source = ".module/fogg-tf/fogg-account"

  remote_region = "${var.remote_region}"
  remote_bucket = "${var.remote_bucket}"
}
