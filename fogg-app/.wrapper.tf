locals {
  org_key = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  env_key = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
  app_key = "${join("_",slice(split("_",var.remote_path),0,3))}/terraform.tfstate"
}

module "app" {
  source = "./module/fogg-tf/fogg-app"

  org_bucket    = "${var.remote_bucket}"
  org_key       = "${local.org_key}"
  org_region    = "${var.remote_region}"
  org_workspace = "${element(split("_",var.remote_path),0)}"

  env_key = "${local.env_key}"
}

data "terraform_remote_state" "env" {
  backend   = "s3"
  workspace = "${terraform.workspace}"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${local.env_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
