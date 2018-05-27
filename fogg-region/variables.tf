variable "account_name" {}
variable "region" {}

output "kms_arn" {
  value = "${module.kms.kms_arn}"
}

output "kms_key_id" {
  value = "${module.kms.kms_key_id}"
}

output "patch_baseline" {
  value = "${aws_ssm_patch_baseline.region.id}"
}
