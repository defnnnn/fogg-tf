variable "meh" {
  default = "feh"
}

output "meh" {
  value = "${var.meh}"
}
