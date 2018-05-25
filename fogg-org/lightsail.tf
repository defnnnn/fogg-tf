resource "aws_lightsail_instance" "org" {
  count             = "${var.want_lightsail}"
  name              = "${var.lightsail_name}"
  availability_zone = "${var.lightsail_zone}"
  blueprint_id      = "ubuntu_16_04_1"
  bundle_id         = "nano_1_0"
  key_pair_name     = "default"
  user_data         = "${data.template_file.lightsail.rendered}"
}

data "template_file" "lightsail" {
  template = "${file(var.lightsail_user_data)}"

  vars {
    zerotier_network = "${var.zerotier_network}"
  }
}
