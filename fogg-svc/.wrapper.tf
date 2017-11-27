locals {
  org_key     = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  env_key     = "${var.remote_env_path}"
  app_key     = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
  service_key = "${join("_",slice(split("_",var.remote_path),0,3))}/terraform.tfstate"
}

module "svc" {
  source = "./module/fogg-tf/fogg-svc"

  global_bucket = "${var.remote_bucket}"
  global_key    = "${local.org_key}"
  global_region = "${var.remote_region}"

  env_bucket = "${var.remote_bucket}"
  env_key    = "env:/${terraform.workspace}/${local.env_key}"
  env_region = "${var.remote_region}"

  app_bucket = "${var.remote_bucket}"
  app_key    = "env:/${terraform.workspace}/${local.app_key}"
  app_region = "${var.remote_region}"
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "env:/${terraform.workspace}/${local.env_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "app" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "env:/${terraform.workspace}/${local.app_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
