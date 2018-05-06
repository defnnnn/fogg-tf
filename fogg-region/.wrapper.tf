locals {
  org_key = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
}

module "region" {
  source = ".module/fogg-tf/fogg-region"

  org_bucket    = "${var.remote_bucket}"
  org_key       = "${local.org_key}"
  org_region    = "${var.remote_region}"
  org_workspace = "${element(split("_",var.remote_path),0)}"
}

data "terraform_remote_state" "org" {
  backend   = "s3"
  workspace = "${element(split("_",var.remote_path),0)}"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${local.org_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
