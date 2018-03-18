resource "aws_vpn_gateway" "env" {
  count = "${var.want_vgw}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_vpn_gateway_attachment" "env" {
  count = "${var.want_vgw}"

  vpc_id         = "${aws_vpc.env.id}"
  vpn_gateway_id = "${aws_vpn_gateway.env.id}"
}
