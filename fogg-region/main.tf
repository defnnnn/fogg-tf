variable "org_bucket" {}
variable "org_key" {}
variable "org_region" {}

data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket         = "${var.org_bucket}"
    key            = "${var.org_key}"
    region         = "${var.org_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
