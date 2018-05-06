provider "aws" {}

resource "aws_organizations_account" "account" {
  name      = "${var.name[terraform.workspace]}"
  email     = "${var.email[terraform.workspace]}"
  role_name = "${var.role_name[terraform.workspace]}"
  count     = "${var.role_name[terraform.workspace] != "" ? 1 : 0}"
}

resource "aws_organizations_account" "custom" {
  name  = "${var.name[terraform.workspace]}"
  email = "${var.email[terraform.workspace]}"
  count = "${var.role_name[terraform.workspace] == "" ? 1 : 0}"
}
