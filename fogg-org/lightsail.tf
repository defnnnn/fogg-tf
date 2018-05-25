data "template_file" "lightsail" {
  template = "${file(var.lightsail_user_data)}"

  vars {
    zerotier_network = "${var.zerotier_network}"
  }
}

resource "aws_lightsail_instance" "org" {
  count             = "${var.want_lightsail}"
  name              = "${var.lightsail_name}"
  availability_zone = "${var.lightsail_zone}"
  blueprint_id      = "ubuntu_16_04_1"
  bundle_id         = "nano_1_0"
  key_pair_name     = "${aws_lightsail_key_pair.org.name}"
  user_data         = "${data.template_file.lightsail.rendered}"
}

resource "aws_lightsail_key_pair" "org" {
  name       = "importing"
  public_key = "${file("etc/ssh-key-pair.pub")}"
}

resource "aws_lightsail_static_ip" "org" {
  count = "${var.want_lightsail}"
  name  = "${var.lightsail_name}"
}

resource "aws_lightsail_static_ip_attachment" "org" {
  count          = "${var.want_lightsail}"
  static_ip_name = "${aws_lightsail_static_ip.org.name}"
  instance_name  = "${aws_lightsail_instance.org.name}"
}
