resource "aws_kms_key" "region" {
  description         = "Organization ${var.account_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
    "Name"      = "${var.account_name}"
  }
}

resource "aws_kms_alias" "ssm_ps" {
  name          = "alias/parameter_store_key"
  target_key_id = "${aws_kms_key.region.key_id}"
}

resource "aws_kms_alias" "credstash" {
  name          = "alias/credstash"
  target_key_id = "${aws_kms_key.region.key_id}"
}