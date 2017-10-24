locals {
  org_key     = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  env_key     = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
  app_key     = "${join("_",slice(split("_",var.remote_path),0,3))}/terraform.tfstate"
  service_key = "${join("_",slice(split("_",var.remote_path),0,4))}/terraform.tfstate"
}

module "instance" {
  source = "module/imma/fogg-instance"

  org_bucket = "${var.remote_bucket}"
  org_key    = "${local.org_key}"
  org_region = "${var.remote_region}"

  env_bucket = "${var.remote_bucket}"
  env_key    = "${local.env_key}"
  env_region = "${var.remote_region}"

  app_bucket = "${var.remote_bucket}"
  app_key    = "${local.app_key}"
  app_region = "${var.remote_region}"

  service_bucket = "${var.remote_bucket}"
  service_key    = "${local.service_key}"
  service_region = "${var.remote_region}"
}

data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${local.org_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${local.env_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "app" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${local.app_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "service" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${local.service_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
