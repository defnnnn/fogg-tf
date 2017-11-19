resource "aws_route53_zone" "public" {
  name = "${var.domain_name}"

  tags {
    "Name"      = "${var.domain_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route53_record" "caa" {
  zone_id = "${aws_route53_zone.public.zone_id}"
  name    = "${var.domain_name}"
  type    = "CAA"
  ttl     = "3600"

  records = [
    "0 issue \"letsencrypt.org\"",
    "0 issuewild \"letsencrypt.org\"",
    "0 issue \"amazon.com\"",
    "0 issuewild \"amazon.com\"",
  ]
}
