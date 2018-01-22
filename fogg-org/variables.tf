variable "domain_name" {}

variable "account_name" {}
variable "global_name" {}

variable "remote_bucket" {}
variable "remote_region" {}

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

variable "want_us_east_1" {
  default = 0
}

variable "want_us_east_2" {
  default = 0
}

variable "want_us_west_2" {
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

variable "want_digitalocean" {
  default = "0"
}

variable "do_instance_count" {
  default = "0"
}

variable "do_data_size" {
  default = "40"
}

variable "do_regions" {
  default = ["sfo2"]
}

variable "do_ssh_key" {
  default = ""
}

variable "want_packet" {
  default = "0"
}

variable "packet_instance_count" {
  default = "0"
}

variable "packet_facility" {
  default = "sjc1"
}

variable "packet_plan" {
  default = "baremetal_0"
}

variable "packet_operating_system" {
  default = "ubuntu_16_04"
}
