variable "region_provider" {}

variable "org_region_index" {
  default = {
    us_east_1 = 0
    us_east_2 = 1
    us_west_2 = 2
  }
}

resource "aws_kms_key" "org" {
  provider            = "${var.region_provider}"
  description         = "Organization ${var.account_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
    "Name"      = "${var.account_name}"
  }
}

output "kms_arn" {
  value = "${aws_kms_key.org.arn}"
}

output "kms_key_id" {
  value = "${aws_kms_key.org.key_id}"
}
