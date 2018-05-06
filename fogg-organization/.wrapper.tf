variable "remote_bucket" {}
variable "remote_region" {}

module "organization" {
  source = ".module/fogg-tf/fogg-organization"

  remote_region = "${var.remote_region}"
  remote_bucket = "${var.remote_bucket}"
}
