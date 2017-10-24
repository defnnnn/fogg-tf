variable "env_name" {}

variable "region" {}

variable "az_count" {}

variable "cidr" {}

variable "public_bits" {
  default = "8"
}

variable "public_subnets" {
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

variable "want_digitalocean" {
  default = "0"
}

variable "want_packet" {
  default = "0"
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
  value = "${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}"
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

output "nat_gateways" {
  value = ["${aws_nat_gateway.env.*.id}"]
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
  value = "${element(coalescelist(aws_kms_key.env.*.arn,list(lookup(data.terraform_remote_state.org.kms_arn,var.region))),0)}"
}

output "kms_key_id" {
  value = "${element(coalescelist(aws_kms_key.env.*.key_id,list(lookup(data.terraform_remote_state.org.kms_key_id,var.region))),0)}"
}

output "env_cert" {
  value = "${data.aws_acm_certificate.env.arn}"
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

variable "want_nat_eip" {
  default = "1"
}

variable "nat_count" {
  default = "0"
}

variable "nat_interface_count" {
  default = 1
}

output "nat_eips" {
  value = ["${module.nat.eips}"]
}

output "nat_sg" {
  value = ["${module.nat.network_sg}"]
}

output "nat_interfaces" {
  value = ["${module.nat.interfaces}"]
}

variable "want_vpn" {
  default = "1"
}

variable "want_vpn_eip" {
  default = "1"
}

variable "vpn_interface_count" {
  default = 1
}

output "vpn_eips" {
  value = ["${module.vpn.eips}"]
}

output "vpn_sg" {
  value = ["${module.vpn.network_sg}"]
}

output "vpn_interfaces" {
  value = ["${module.vpn.interfaces}"]
}
