variable "domain_name" {}

variable "account_name" {}

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
  value = "${aws_route53_zone.public.zone_id}"
}

output "public_zone_servers" {
  value = "${aws_route53_zone.public.name_servers}"
}

output "config_sqs" {
  value = "${aws_sqs_queue.config.id}"
}

output "cloudfront" {
  value = "${aws_cloudfront_distribution.website.domain_name}"
}

output "kms_arn" {
  value = {
    us-east-1      = "${aws_kms_key.org_us_east_1.arn}"
    us-east-2      = "${aws_kms_key.org_us_east_2.arn}"
    us-west-2      = "${aws_kms_key.org_us_west_2.arn}"
    eu-west-1      = "${aws_kms_key.org_eu_west_1.arn}"
    eu-central-1   = "${aws_kms_key.org_eu_central_1.arn}"
    ap-southeast-2 = "${aws_kms_key.org_ap_southeast_2.arn}"
  }
}

output "kms_key_id" {
  value = {
    us-east-1      = "${aws_kms_key.org_us_east_1.key_id}"
    us-east-2      = "${aws_kms_key.org_us_east_2.key_id}"
    us-west-2      = "${aws_kms_key.org_us_west_2.key_id}"
    eu-west-1      = "${aws_kms_key.org_eu_west_1.key_id}"
    eu-central-1   = "${aws_kms_key.org_eu_central_1.key_id}"
    ap-southeast-2 = "${aws_kms_key.org_ap_southeast_2.key_id}"
  }
}

output "wildcard_cert" {
  value = "${data.aws_acm_certificate.website.arn}"
}
