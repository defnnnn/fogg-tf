module "app" {
  source = "module/imma/fogg-app"

  global_region = "${var.remote_region}"
  global_bucket = "${var.remote_bucket}"

  global_key = "${var.remote_org_path}"
  env_key    = "${var.remote_env_path}"
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${var.remote_env_path}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
