variable "domain_name" {}

variable "account_name" {}
variable "global_name" {}

variable "remote_bucket" {}
variable "remote_region" {}

variable "want_lightsail" {
  default = 0
}

variable "lightsail_name" {
  default = ""
}

variable "lightsail_zone" {
  default = ""
}

variable "zerotier_network" {
  default = ""
}

variable "lightsail_user_data" {
  default = ".module/fogg-tf/init/user-data-lightsail.template"
}

variable "want_macie" {
  default = 0
}

variable "want_config" {
  default = 0
}

variable "want_guard_duty" {
  default = 0
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

variable "want_us_east_1" {
  default = 0
}

variable "want_us_east_2" {
  default = 0
}

variable "want_us_west_1" {
  default = 0
}

variable "want_us_west_2" {
  default = 0
}

variable "want_ca_central_1" {
  default = 0
}

variable "want_eu_west_1" {
  default = 0
}

variable "want_eu_central_1" {
  default = 0
}

variable "want_ap_southeast_2" {
  default = 0
}

output "api_gateway_arn" {
  value = "${aws_iam_role.api_gateway.arn}"
}

output "inventory_arn" {
  value = "${aws_s3_bucket.inventory.arn}"
}

output "inventory_bucket" {
  value = "${aws_s3_bucket.inventory.bucket}"
}

output "inventory_region" {
  value = "${aws_s3_bucket.inventory.region}"
}
