locals {
  org_key     = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  env_key     = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
  app_key     = "${join("_",slice(split("_",var.remote_path),0,3))}/terraform.tfstate"
  service_key = "${join("_",slice(split("_",var.remote_path),0,4))}/terraform.tfstate"
}

module "svc" {
  source = "./module/fogg-tf/fogg-svc"

  org_bucket = "${var.remote_bucket}"
  org_key    = "env:/${element(split("_",var.remote_path),0)}/${local.org_key}"
  org_region = "${var.remote_region}"

  env_key = "env:/${terraform.workspace}/${local.env_key}"
  app_key = "env:/${terraform.workspace}/${local.app_key}"
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
