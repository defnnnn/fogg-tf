resource "packet_project" "service" {
  name  = "${local.service_name}"
  count = "${var.want_packet}"
}

resource "packet_device" "service" {
  hostname         = "packet-${data.terraform_remote_state.app.app_name}-${var.service_name}${count.index+1}.${data.terraform_remote_state.env.private_zone_name}" /*"*/
  project_id       = "${packet_project.service.id}"
  facility         = "${var.packet_facility}"
  plan             = "${var.packet_plan}"
  billing_cycle    = "hourly"
  operating_system = "${var.packet_operating_system}"
  count            = "${var.want_packet*var.packet_instance_count}"
}

resource "packet_volume" "service" {
  project_id    = "${packet_project.service.id}"
  facility      = "${var.packet_facility}"
  plan          = "storage_1"
  billing_cycle = "hourly"
  size          = "40"
  count         = "${var.want_packet}"
}

resource "aws_route53_record" "packet_instance" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${local.service_name}${count.index}-packet.${data.terraform_remote_state.org.domain_name}"
  type    = "A"
  ttl     = "60"
  records = ["${element(packet_device.service.*.network.0.address,count.index)}"]
  count   = "${var.want_packet*var.packet_instance_count}"
}
