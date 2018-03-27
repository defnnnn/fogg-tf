resource "aws_route53_zone" "public" {
  name = "${var.domain_name}."

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

resource "aws_route53_record" "mx_google" {
  zone_id = "${aws_route53_zone.public.zone_id}"
  name    = "${var.domain_name}"
  type    = "MX"
  ttl     = "3600"
  records = ["1 aspmx.l.google.com", "5 alt1.aspmx.l.google.com", "5 alt2.aspmx.l.google.com", "10 aspmx2.googlemail.com", "10 aspmx3.googlemail.com"]
  count   = "${var.want_google_mx}"
}
