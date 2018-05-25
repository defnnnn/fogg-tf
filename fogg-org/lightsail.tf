resource "aws_lightsail_instance" "org" {
  count             = "${var.want_lightsail}"
  name              = "${var.lightsail_name}"
  availability_zone = "${var.lightsail_zone}"
  blueprint_id      = "ubuntu_16_04_1"
  bundle_id         = "nano_1_0"
  key_pair_name     = "default"
}
