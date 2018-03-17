data "aws_network_interface" "network" {
  filter {
    name   = "availability-zone"
    values = ["${var.instance_az}"]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.eni_name}"]
  }
}

resource "aws_network_interface_attachment" "network" {
  instance_id          = "${var.instance_id}"
  network_interface_id = "${data.aws_network_interface.network.id}"
  device_index         = 1
  count                = "${var.mcount}"
}
