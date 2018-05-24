resource "aws_guardduty_detector" "us_east_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.us_east_1"
  enable   = true
}

resource "aws_guardduty_detector" "us_east_2" {
  count    = "${var.want_guard_duty}"
  provider = "aws.us_east_2"
  enable   = true
}

resource "aws_guardduty_detector" "us_west_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.us_west_1"
  enable   = true
}

resource "aws_guardduty_detector" "us_west_2" {
  count    = "${var.want_guard_duty}"
  provider = "aws.us_west_2"
  enable   = true
}

resource "aws_guardduty_detector" "ca_central_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.ca_central_1"
  enable   = true
}

resource "aws_guardduty_detector" "sa_east_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.sa_east_1"
  enable   = true
}

resource "aws_guardduty_detector" "eu_central_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.eu_central_1"
  enable   = true
}

resource "aws_guardduty_detector" "eu_west_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.eu_west_1"
  enable   = true
}

resource "aws_guardduty_detector" "eu_west_2" {
  count    = "${var.want_guard_duty}"
  provider = "aws.eu_west_2"
  enable   = true
}

resource "aws_guardduty_detector" "eu_west_3" {
  count    = "${var.want_guard_duty}"
  provider = "aws.eu_west_3"
  enable   = true
}

resource "aws_guardduty_detector" "ap_northeast_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.ap_northeast_1"
  enable   = true
}

resource "aws_guardduty_detector" "ap_northeast_2" {
  count    = "${var.want_guard_duty}"
  provider = "aws.ap_northeast_2"
  enable   = true
}

resource "aws_guardduty_detector" "ap_southeast_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.ap_southeast_1"
  enable   = true
}

resource "aws_guardduty_detector" "ap_southeast_2" {
  count    = "${var.want_guard_duty}"
  provider = "aws.ap_southeast_2"
  enable   = true
}

resource "aws_guardduty_detector" "ap_south_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.ap_south_1"
  enable   = true
}
