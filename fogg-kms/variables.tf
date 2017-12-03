variable "account_name" {}

variable "mcount" {
  default = 1
}

output "kms_arn" {
  value = "${element(concat(aws_kms_key.region.*.arn,list("")),0)}"
}

output "kms_key_id" {
  value = "${element(concat(aws_kms_key.region.*.key_id,list("")),0)}"
}
