module "nat" {
  source = "./module/network"

  vpc_id   = "${aws_vpc.env.id}"
  env_name = "${var.env_name}"

  env_sg  = "${aws_security_group.env.id}"
  subnets = ["${aws_subnet.private.*.id}"]

  network_name    = "nat"
  interface_count = "${var.nat_interface_count}"
  want_eip        = "${var.want_nat_eip}"
}

resource "aws_security_group_rule" "forward_allow_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}

resource "aws_security_group_rule" "forward_allow_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}
