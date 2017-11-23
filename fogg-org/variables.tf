variable "domain_name" {}

variable "account_name" {}
variable "global_name" {}

variable "remote_bucket" {}
variable "remote_region" {}

variable "acm_arn" {}

variable "acm" {
  default = {}
}

variable "want_macie" {
  default = 1
}

variable "cdn_secret" {
  default = "not-a-secret"
}

output "aws_account_id" {
  value = "${data.aws_caller_identity.current.account_id}"
}

output "account_name" {
  value = "${var.account_name}"
}

output "domain_name" {
  value = "${var.domain_name}"
}

output "public_zone_id" {
  value = "${data.aws_route53_zone.public.zone_id}"
}

output "config_sqs" {
  value = "${aws_sqs_queue.config.id}"
}

output "cloudfront" {
  value = "${aws_cloudfront_distribution.website.domain_name}"
}

output "kms_arn" {
  value = {
    us-east-1      = "${module.kms_us_east_1.kms_arn}"
    us-east-2      = "${module.kms_us_east_2.kms_arn}"
    us-west-2      = "${module.kms_us_west_2.kms_arn}"
    eu-west-1      = "${module.kms_eu_west_1.kms_arn}"
    eu-central-1   = "${module.kms_eu_central_1.kms_arn}"
    ap-southeast-2 = "${module.kms_ap_southeast_2.kms_arn}"
  }
}

output "kms_key_id" {
  value = {
    us-east-1      = "${module.kms_us_east_1.kms_key_id}"
    us-east-2      = "${module.kms_us_east_2.kms_key_id}"
    us-west-2      = "${module.kms_us_west_2.kms_key_id}"
    eu-west-1      = "${module.kms_eu_west_1.kms_key_id}"
    eu-central-1   = "${module.kms_eu_central_1.kms_key_id}"
    ap-southeast-2 = "${module.kms_ap_southeast_2.kms_key_id}"
  }
}

output "wildcard_cert" {
  value = "${var.acm_arn}"
}

output "acm_arn" {
  value = "${var.acm_arn}"
}

output "acm" {
  value = "${var.acm}"
}
