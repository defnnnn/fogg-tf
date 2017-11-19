variable "account_name" {}

output "kms_arn" {
  value = "aws_kms_key.region.arn"
}

output "kms_key_id" {
  value = "aws_kms_key.region.key_id"
}
