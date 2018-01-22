resource "digitalocean_volume" "service" {
  region      = "${var.do_region}"
  name        = "${local.service_name}${count.index}"
  size        = "${var.do_data_size}"
  description = "${local.service_name}${count.index} data"
  count       = "${var.want_digitalocean*var.do_instance_count}"
}

resource "digitalocean_droplet" "service" {
  name       = "${local.service_name}${count.index}"
  ssh_keys   = ["${var.do_ssh_key}"]
  region     = "${var.do_region}"
  image      = "ubuntu-16-04-x64"
  size       = "512mb"
  volume_ids = ["${element(digitalocean_volume.service.*.id,count.index)}"]
  count      = "${var.want_digitalocean*var.do_instance_count}"
}

resource "digitalocean_firewall" "service" {
  name  = "${local.service_name}.${data.terraform_remote_state.org.domain_name}"
  count = "${signum(var.want_digitalocean*var.do_instance_count)}"

  droplet_ids = ["${digitalocean_droplet.service.*.id}"]

  inbound_rule = [
    {
      protocol         = "udp"
      port_range       = "9993"
      source_addresses = ["0.0.0.0/0"]
    },
    {
      protocol         = "tcp"
      port_range       = "9993"
      source_addresses = ["0.0.0.0/0"]
    },
    {
      protocol         = "tcp"
      port_range       = "22"
      source_addresses = ["0.0.0.0/0"]
    },
  ]

  outbound_rule = [
    {
      protocol              = "icmp"
      port_range            = "1-65535"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol              = "tcp"
      port_range            = "all"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol              = "udp"
      port_range            = "all"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
  ]
}

resource "aws_route53_record" "do_instance" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${local.service_name}${count.index}-do.${data.terraform_remote_state.org.domain_name}"

  /*"*/

  type    = "A"
  ttl     = "60"
  records = ["${digitalocean_droplet.service.*.ipv4_address[count.index]}"]
  count   = "${var.want_digitalocean*var.do_instance_count}"
}
