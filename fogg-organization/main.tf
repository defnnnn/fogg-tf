provider "aws" {}

data "terraform_remote_state" "organization" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "organization/terraform.tfstate"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

resource "aws_organizations_organization" "organization" {
  feature_set = "ALL"
}
