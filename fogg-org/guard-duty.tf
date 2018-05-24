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

resource "aws_guardduty_detector" "ca_central_1" {
  count    = "${var.want_guard_duty}"
  provider = "aws.ca_central_1"
  enable   = true
}

resource "aws_guardduty_detector" "us_west_2" {
  count    = "${var.want_guard_duty}"
  provider = "aws.us_west_2"
  enable   = true
}
