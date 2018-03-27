locals {
  org_key     = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  reg_key     = "${join("_",slice(split("_",var.remote_path),0,1))}_region/terraform.tfstate"
  env_key     = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
  app_key     = "${join("_",slice(split("_",var.remote_path),0,3))}/terraform.tfstate"
  service_key = "${join("_",slice(split("_",var.remote_path),0,4))}/terraform.tfstate"
}

module "svc" {
  source = "./module/fogg-tf/fogg-svc"

  org_bucket    = "${var.remote_bucket}"
  org_key       = "${local.org_key}"
  org_region    = "${var.remote_region}"
  org_workspace = "${element(split("_",var.remote_path),0)}"

  reg_key = "${local.reg_key}"
  env_key = "${local.env_key}"
  app_key = "${local.app_key}"
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

data "terraform_remote_state" "reg" {
  backend   = "s3"
  workspace = "${var.region}"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${local.reg_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
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

data "terraform_remote_state" "app" {
  backend   = "s3"
  workspace = "${terraform.workspace}"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${local.app_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
