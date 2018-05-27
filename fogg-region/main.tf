variable "org_bucket" {}
variable "org_workspace" {}
variable "org_key" {}
variable "org_region" {}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "terraform_remote_state" "org" {
  backend   = "s3"
  workspace = "${var.org_workspace}"

  config {
    bucket         = "${var.org_bucket}"
    key            = "${var.org_key}"
    region         = "${var.org_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

locals {
  public_key = "${file("etc/ssh-key-pair.pub")}"
}

resource "aws_key_pair" "region" {
  key_name   = "default"
  public_key = "${local.public_key}"
}

module "kms" {
  source = ".module/fogg-tf/fogg-kms"

  account_name = "${var.account_name}"
  region       = "${var.region}"
  mcount       = 1
}

#data "aws_ami" "block" {
#  most_recent = true
#
#  filter {
#    name   = "state"
#    vvar.account_namealues = ["available"]
#  }
#
#  filter {
#    name   = "tag:Block"
#    values = ["block-ubuntu-*"]
#  }
#
#  owners = ["self"]
#}

data "aws_ami" "region" {
  provider    = "aws.us_east_1"
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-2017.09.*-amazon-ecs-optimized"]
  }

  owners = ["amazon"]
}

#module "ami" {
#  source = ".module/fogg-tf/fogg-ami-copy"
#
#  source_ami_region = "us-east-1"
#  source_ami_id     = "${data.aws_ami.region.image_id}"
#}

resource "aws_acm_certificate" "env" {
  domain_name               = "*.${data.terraform_remote_state.org.domain_name}"
  subject_alternative_names = ["${data.terraform_remote_state.org.domain_name}"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "acm_validation" {
  name    = "${aws_acm_certificate.env.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.env.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  records = ["${aws_acm_certificate.env.domain_validation_options.0.resource_record_value}."]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "env" {
  certificate_arn         = "${aws_acm_certificate.env.arn}"
  validation_record_fqdns = ["${aws_route53_record.acm_validation.fqdn}"]
}

resource "aws_api_gateway_account" "region" {
  cloudwatch_role_arn = "${data.terraform_remote_state.org.api_gateway_arn}"
}

resource "aws_ssm_resource_data_sync" "region" {
  name = "${var.region}"

  s3_destination = {
    bucket_name = "${data.terraform_remote_state.org.inventory_bucket}"
    region      = "${data.terraform_remote_state.org.inventory_region}"
  }
}

resource "aws_ssm_patch_baseline" "region" {
  name             = "${var.region}"
  operating_system = "AMAZON_LINUX"

  approval_rule {
    approve_after_days  = 0
    enable_non_security = 1

    patch_filter {
      key    = "PRODUCT"
      values = ["AmazonLinux2017.09", "AmazonLinux2018.03"]
    }
  }
}
