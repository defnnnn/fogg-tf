variable "org_region" {}
variable "org_bucket" {}

variable "org_key" {}
variable "env_key" {}

data "terraform_remote_state" "global" {
  backend = "s3"

  config {
    bucket         = "${var.org_bucket}"
    key            = "${var.org_key}"
    region         = "${var.org_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket         = "${var.org_bucket}"
    key            = "${var.env_key}"
    region         = "${var.org_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

resource "aws_security_group" "app" {
  name        = "${data.terraform_remote_state.env.env_name}-${var.app_name}"
  description = "Application ${var.app_name}"
  vpc_id      = "${data.terraform_remote_state.env.vpc_id}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${var.app_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_kms_key" "app" {
  description         = "Application ${var.app_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "Name"      = "${data.terraform_remote_state.env.env_name}-${var.app_name}"
  }
}

resource "aws_kms_alias" "app" {
  name          = "alias/${data.terraform_remote_state.env.env_name}-${var.app_name}"
  target_key_id = "${aws_kms_key.app.id}"
}

resource "aws_codecommit_repository" "app" {
  repository_name = "${data.terraform_remote_state.env.env_name}-${var.app_name}"
  description     = "Repo for ${data.terraform_remote_state.env.env_name}-${var.app_name} app"
}

resource "aws_ssm_parameter" "fogg_app" {
  name  = "${data.terraform_remote_state.env.env_name}-${var.app_name}.fogg_app"
  type  = "String"
  value = "${var.app_name}"
}

resource "aws_ssm_parameter" "fogg_app_sg" {
  name  = "${data.terraform_remote_state.env.env_name}-${var.app_name}.fogg_app_sg"
  type  = "String"
  value = "${aws_security_group.app.id}"
}

resource "aws_ecr_repository" "app" {
  name = "${data.terraform_remote_state.env.env_name}-${var.app_name}"
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = "${aws_ecr_repository.app.name}"

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 10 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
