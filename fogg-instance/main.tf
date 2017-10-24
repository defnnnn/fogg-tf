variable "org_bucket" {}
variable "org_key" {}
variable "org_region" {}

variable "env_bucket" {}
variable "env_key" {}
variable "env_region" {}

variable "app_bucket" {}
variable "app_key" {}
variable "app_region" {}

variable "service_bucket" {}
variable "service_key" {}
variable "service_region" {}

data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket         = "${var.org_bucket}"
    key            = "${var.org_key}"
    region         = "${var.org_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket         = "${var.env_bucket}"
    key            = "${var.env_key}"
    region         = "${var.env_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "app" {
  backend = "s3"

  config {
    bucket         = "${var.app_bucket}"
    key            = "${var.app_key}"
    region         = "${var.app_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "service" {
  backend = "s3"

  config {
    bucket         = "${var.service_bucket}"
    key            = "${var.service_key}"
    region         = "${var.service_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "aws_instance" "this" {
  filter {
    name   = "tag:Name"
    values = ["${var.instance_name}"]
  }
}

data "aws_route53_zone" "public" {
  name         = "${coalesce(var.public_zone,data.terraform_remote_state.org.domain_name)}"
  private_zone = false
}

resource "aws_eip" "this" {
  vpc   = true
  count = "${var.want_eip}"
}

resource "aws_route53_record" "public" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name    = "${var.public_name}.${data.aws_route53_zone.public.name}"
  type    = "A"
  ttl     = "60"
  records = ["${aws_eip.this.public_ip}"]
  count   = "${var.want_eip}"
}

resource "aws_route53_record" "public_instance" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name    = "${var.public_name}.${data.aws_route53_zone.public.name}"
  type    = "A"
  ttl     = "60"
  records = ["${ data.aws_instance.this.public_ip}"]
  count   = "${var.public_name == "" ? 0 : (var.want_eip ? 0 : 1)}"
}

resource "aws_eip_association" "this" {
  instance_id   = "${data.aws_instance.this.id}"
  allocation_id = "${aws_eip.this.id}"
  count         = "${var.want_eip}"
}

resource "aws_ebs_volume" "this" {
  availability_zone = "${data.aws_instance.this.availability_zone}"
  size              = "${element(var.ebs_size,count.index)}"
  count             = "${var.ebs_count}"

  tags {
    ManagedBy = "terraform"
    Env       = "${data.terraform_remote_state.env.env_name}"
    App       = "${data.terraform_remote_state.app.app_name}"
    Service   = "${data.terraform_remote_state.service.service_name}"
    Name      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${data.terraform_remote_state.service.service_name}"
  }
}

resource "aws_volume_attachment" "this" {
  device_name = "${var.devices[count.index]}"
  volume_id   = "${aws_ebs_volume.this.*.id[count.index]}"
  instance_id = "${data.aws_instance.this.id}"
  count       = "${var.ebs_count}"
}
