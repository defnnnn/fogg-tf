variable "instance_name" {}

variable "ebs_count" {
  default = "0"
}

variable "ebs_size" {
  default = [2]
}

variable "want_eip" {
  default = "0"
}

variable "devices" {
  default = ["/dev/sdh", "/dev/sdi"]
}

variable "public_zone" {
  default = ""
}

variable "public_name" {
  default = ""
}

output "eip" {
  value = "${aws_eip.this.public_ip}"
}

output "private_ip" {
  value = "${data.aws_instance.this.private_ip}"
}

output "instance_id" {
  value = "${data.aws_instance.this.id}"
}

output "az" {
  value = "${data.aws_instance.this.availability_zone}"
}
