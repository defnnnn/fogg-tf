locals {
  org_key = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  env_key = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
}

module "env" {
  source = "./module/fogg-tf/fogg-env"

  org_bucket = "${var.remote_bucket}"
  org_key    = "env:/${element(split("_",var.remote_path),0)}/${local.org_key}"
  org_region = "${var.remote_region}"
}

data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "env:/${element(split("_",var.remote_path),0)}/${local.org_key}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
