variable "meh" {
  default = "1"
}

output "meh" {
  value = "${var.meh}"
}
