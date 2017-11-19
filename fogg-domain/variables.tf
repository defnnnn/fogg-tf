variable "domain_name" {}

output "zone_name" {
  value = "${var.domain_name}"
}

output "zone_id" {
  value = "${aws_route53_zone.public.zone_id}"
}

output "zone_servers" {
  value = "${aws_route53_zone.public.name_servers}"
}
