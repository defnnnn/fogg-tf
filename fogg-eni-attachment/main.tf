data "external" "network" {
  program = ["../../imma-tf/bin/lookup-network-interface", "${var.instance_az}", "${var.eni_name}"]
}

resource "aws_network_interface_attachment" "network" {
  instance_id          = "${var.instance_id}"
  network_interface_id = "${element(split(" ",lookup(data.external.network.result,var.instance_az)),0)}"
  device_index         = 1
}

output "network_interface" {
  value = "${lookup(data.external.network.result,var.instance_az)}"
}
