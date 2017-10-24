variable efs_name {}

variable az_count {}

variable subnets {
  default = []
}

variable want_efs {
  default = "1"
}

variable "vpc_id" {}

variable "env_name" {}

data "aws_vpc" "current" {
  id = "${var.vpc_id}"
}

resource "aws_security_group" "fs" {
  name        = "${var.efs_name}-efs"
  description = "${var.efs_name}"
  vpc_id      = "${data.aws_vpc.current.id}"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = ["description"]
  }

  tags {
    "Name"      = "${var.efs_name}-network-efs"
    "Env"       = "${var.env_name}"
    "App"       = "network"
    "Service"   = "efs"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_efs}"
}

resource "aws_security_group_rule" "fs_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.fs.id}"

  count = "${var.want_efs}"
}

resource "aws_efs_file_system" "fs" {
  tags {
    "Name"      = "${var.efs_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_efs}"
}

resource "aws_efs_mount_target" "fs" {
  file_system_id  = "${aws_efs_file_system.fs.id}"
  subnet_id       = "${element(var.subnets,count.index)}"
  security_groups = ["${aws_security_group.fs.id}"]
  count           = "${var.az_count*var.want_efs}"
}

output "efs_dns_names" {
  value = ["${aws_efs_mount_target.fs.*.dns_name}"]
}

output "efs_sg" {
  value = "${aws_security_group.fs.id}"
}
