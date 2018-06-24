variable "env_name" {}

variable "region" {}

variable "az_count" {}

variable "cidr" {}

variable "ipv6_public_bits" {
  default = "8"
}

variable "ipv6_public_subnets" {
  default = []
}

variable "public_bits" {
  default = "8"
}

variable "public_subnets" {
  default = []
}

variable "ipv6_private_bits" {
  default = "8"
}

variable "ipv6_private_subnets" {
  default = []
}

variable "private_bits" {
  default = "8"
}

variable "private_subnets" {
  default = []
}

variable "env_zone" {
  default = ""
}

variable "env_domain_name" {
  default = ""
}

variable "associate_zones" {
  default = []
}

variable "associate_count" {
  default = "0"
}

variable "want_efs" {
  default = "1"
}

variable "want_ipv6" {
  default = "1"
}

variable "want_kms" {
  default = "0"
}

variable "want_nlb" {
  default = "0"
}

variable "want_sd" {
  default = "1"
}

output "vpc_id" {
  value = "${aws_vpc.env.id}"
}

output "igw_id" {
  value = "${aws_internet_gateway.env.id}"
}

output "egw_id" {
  value = "${aws_egress_only_internet_gateway.env.id}"
}

output "private_zone_id" {
  value = "${aws_route53_zone.private.zone_id}"
}

output "private_zone_servers" {
  value = "${aws_route53_zone.private.name_servers}"
}

output "private_zone_name" {
  value = "${local.private_zone_name}"
}

output "private_sd_zone_name" {
  value = "${element(coalescelist(aws_service_discovery_private_dns_namespace.env.*.name,list("")),0)}"
}

output "private_sd_zone_id" {
  value = "${element(coalescelist(aws_service_discovery_private_dns_namespace.env.*.hosted_zone,list("")),0)}"
}

output "private_sd_id" {
  value = "${element(coalescelist(aws_service_discovery_private_dns_namespace.env.*.id,list("")),0)}"
}

output "sg_efs" {
  value = "${module.efs.efs_sg}"
}

output "sg_env" {
  value = "${aws_security_group.env.id}"
}

output "s3_bucket_prefix" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}"
}

output "s3_env_meta" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-meta"
}

output "s3_env_s3" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-s3"
}

output "s3_env_ses" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-ses"
}

output "public_subnets" {
  value = ["${aws_subnet.public.*.id}"]
}

output "private_subnets" {
  value = ["${aws_subnet.private.*.id}"]
}

output "fake_subnets" {
  value = ["${null_resource.fake.*.triggers.meh}"]
}

output "env_name" {
  value = "${var.env_name}"
}

output "route_tables" {
  value = ["${concat(aws_route_table.private.*.id,aws_route_table.public.*.id)}"]
}

output "route_table_public" {
  value = ["${aws_route_table.public.*.id}"]
}

output "route_table_private" {
  value = ["${aws_route_table.private.*.id}"]
}

output "s3_endpoint_id" {
  value = "${aws_vpc_endpoint.s3.id}"
}

output "dynamodb_endpoint_id" {
  value = "${aws_vpc_endpoint.dynamodb.id}"
}

output "egw_gateway" {
  value = "${aws_egress_only_internet_gateway.env.id}"
}

output "kms_arn" {
  value = "${element(coalescelist(aws_kms_key.env.*.arn,list(data.terraform_remote_state.reg.kms_arn)),0)}"
}

output "kms_key_id" {
  value = "${element(coalescelist(aws_kms_key.env.*.key_id,list(data.terraform_remote_state.reg.kms_key_id)),0)}"
}

locals {
  env_cert = "${data.aws_acm_certificate.env.arn}"
}

output "env_region" {
  value = "${var.region}"
}

output "env_cert" {
  value = "${local.env_cert}"
}

output "env_cidr" {
  value = "${var.cidr}"
}

output "api_gateway" {
  value = "${aws_api_gateway_rest_api.env.id}"
}

output "api_gateway_resource" {
  value = "${aws_api_gateway_rest_api.env.root_resource_id}"
}

variable "want_nat" {
  default = "0"
}

variable "nat_count" {
  default = "0"
}

variable "nat_interface_count" {
  default = 1
}

output "nat_sg" {
  value = ["${module.nat.network_sg}"]
}

output "nat_interfaces" {
  value = ["${module.nat.interfaces}"]
}

variable "want_vgw" {
  default = "1"
}

output "vgw_id" {
  value = "${element(concat(aws_vpn_gateway.env.*.id,list("0")),0)}"
}

variable "want_private_api" {
  default = 0
}

output "rc_invoke_url" {
  value = "${module.stage_rc.invoke_url}"
}

output "live_invoke_url" {
  value = "${module.stage_live.invoke_url}"
}
