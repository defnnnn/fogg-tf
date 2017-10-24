variable "org" {
  default = []
}

variable "service" {
  default = {}
}

variable "az_count" {}

variable "service_name" {}

variable "display_name" {
  default = ""
}

variable "public_network" {
  default = "0"
}

variable "want_elasticache" {
  default = "0"
}

variable "public_lb" {
  default = "0"
}

variable "want_nlb" {
  default = "0"
}

variable "want_alb" {
  default = "0"
}

variable "want_efs" {
  default = "0"
}

variable "want_vpn" {
  default = "1"
}

variable "want_nat" {
  default = "0"
}

variable "want_nat_instance" {
  default = "1"
}

variable "want_nat_interface" {
  default = "1"
}

variable "want_ipv6" {
  default = "0"
}

variable "want_subnets" {
  default = "1"
}

variable "want_kms" {
  default = "0"
}

variable "want_digitalocean" {
  default = "0"
}

variable "do_instance_count" {
  default = "0"
}

variable "do_region" {
  default = "sfo1"
}

variable "want_packet" {
  default = "0"
}

variable "packet_instance_count" {
  default = "0"
}

variable "packet_facility" {
  default = "sjc1"
}

variable "packet_plan" {
  default = "baremetal_0"
}

variable "packet_operating_system" {
  default = "ubuntu_16_04"
}

variable "user_data" {
  default = "module/init/user-data.template"
}

variable "service_bits" {}

variable "instance_count" {
  default = 0
}

variable "instance_count_sf" {
  default = 0
}

variable "asg_count" {
  default = 1
}

variable "sf_count" {
  default = 0
}

variable "asg_name" {
  default = ["live", "rc"]
}

variable "instance_type" {
  default = ["t2.nano"]
}

variable "instance_type_sf" {
  default = "c4.large"
}

variable "spot_price_sf" {
  default = "0.002"
}

variable "ami_id" {
  default = [""]
}

variable "root_volume_size" {
  default = ["40"]
}

variable "min_size" {
  default = ["0"]
}

variable "max_size" {
  default = ["5"]
}

variable "termination_policies" {
  default = ["OldestInstance"]
}

variable "block" {
  default = "block-ubuntu"
}

variable "key_name" {
  default = "default"
}

variable "amazon_linux" {
  default = false
}

output "asg_names" {
  value = ["${aws_autoscaling_group.service.*.name}"]
}

output "service_name" {
  value = "${var.service_name}"
}

output "env_sg" {
  value = "${data.terraform_remote_state.env.sg_env}"
}

output "app_sg" {
  value = "${data.terraform_remote_state.app.app_sg}"
}

output "service_sg" {
  value = "${aws_security_group.service.id}"
}

output "service_subnets" {
  value = ["${concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id)}"]
}

output "key_name" {
  value = "${var.key_name}"
}

output "service_sqs" {
  value = ["${aws_sqs_queue.service.*.id}"]
}

output "service_iam_role" {
  value = "${aws_iam_role.service.name}"
}

output "service_iam_profile" {
  value = "${aws_iam_instance_profile.service.name}"
}

output "service_ami" {
  value = "${element(aws_launch_configuration.service.*.image_id,0)}"
}

output "block" {
  value = "${var.block}"
}

output "route_tables" {
  value = ["${aws_route_table.service.*.id}"]
}

output "region" {
  value = "${var.env_region}"
}

output "role" {
  value = "${aws_iam_role.service.arn}"
}

output "private_ips" {
  value = ["${aws_instance.service.*.private_ip}"]
}

output "public_ips" {
  value = ["${aws_instance.service.*.public_ip}"]
}

output "instance_ids" {
  value = ["${aws_instance.service.*.id}"]
}

output "instance_azs" {
  value = ["${aws_instance.service.*.availability_zones}"]
}

output "packet_project_id" {
  value = "${packet_project.service.id}"
}

output "packet_public_ips" {
  value = "${packet_device.service.*.network.0.address}"
}

output "kms_arn" {
  value = "${element(coalescelist(aws_kms_key.service.*.arn,list(data.terraform_remote_state.env.kms_arn)),0)}"
}

output "kms_key_id" {
  value = "${element(coalescelist(aws_kms_key.service.*.key_id,list(data.terraform_remote_state.env.kms_key_id)),0)}"
}
