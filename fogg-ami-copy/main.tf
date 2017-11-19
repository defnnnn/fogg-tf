resource "aws_ami_copy" "region" {
  name = "golden-${uuid()}"

  source_ami_id     = "${var.source_ami_id}"
  source_ami_region = "${var.source_ami_region}"

  tags {
    Block = "golden"
  }

  lifecycle {
    ignore_changes = ["name", "description"]
  }
}
