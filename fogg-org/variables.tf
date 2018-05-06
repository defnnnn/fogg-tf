variable "domain_name" {}

variable "account_name" {}
variable "global_name" {}

variable "remote_bucket" {}
variable "remote_region" {}

variable "want_macie" {
  default = 1
}

variable "want_config" {
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

variable "want_eu_west_1" {
  default = 0
}

variable "want_eu_central_1" {
  default = 0
}

variable "want_ap_southeast_2" {
  default = 0
}

variable "want_digitalocean" {
  default = "0"
}

variable "do_instance_count" {
  default = "0"
}

variable "do_eip_count" {
  default = "0"
}

variable "do_data_size" {
  default = "40"
}

variable "do_regions" {
  default = ["sfo2"]
}

variable "do_hostnames" {
  default = []
}

variable "do_zones" {
  default = []
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

variable "user_data" {
  default = ".module/fogg-tf/init/user-data-digitalocean.template"
}

output "do_bastion_ips" {
  value = ["${digitalocean_droplet.service.*.ipv4_address}"]
}

output "do_bastion_cidrs" {
  value = ["${formatlist("%s/32",digitalocean_droplet.service.*.ipv4_address)}"]
}

output "api_gateway_arn" {
  value = "${aws_iam_role.api_gateway.arn}"
}
