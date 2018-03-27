variable "org_bucket" {}
variable "org_key" {}
variable "org_region" {}

data "terraform_remote_state" "org" {
  backend = "s3"

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
  source = "./module/fogg-tf/fogg-kms"

  account_name = "${var.account_name}"
  mcount       = 1
}

data "aws_ami" "block" {
  most_recent = true

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:Block"
    values = ["block-ubuntu-*"]
  }

  owners = ["self"]
}

module "ami" {
  source = "./module/fogg-tf/fogg-ami-copy"

  source_ami_region = "us-east-1"
  source_ami_id     = "${data.aws_ami.block.image_id}"
}

resource "aws_acm_certificate" "env" {
  domain_name               = "*.${data.terraform_remote_state.org.domain_name}"
  subject_alternative_names = ["${data.terraform_remote_state.org.domain_name}"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "acm_validation" {
  name    = "${aws_acm_certificate.env.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.env.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  records = ["${aws_acm_certificate.env.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "env" {
  certificate_arn         = "${aws_acm_certificate.env.arn}"
  validation_record_fqdns = ["${aws_route53_record.acm_validation.fqdn}"]
}

resource "aws_api_gateway_account" "region" {
  cloudwatch_role_arn = "${data.terraform_remote_state.org.api_gateway_arn}"
}
