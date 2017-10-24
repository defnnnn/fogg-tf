module "env" {
  source = "./module/fogg-env"

  global_bucket = "${var.remote_bucket}"
  global_key    = "${var.remote_org_path}"
  global_region = "${var.remote_region}"
}

data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${var.remote_org_path}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
