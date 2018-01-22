resource "digitalocean_volume" "service" {
  region      = "${var.do_region}"
  name        = "${var.account_name}-${var.do_region}${count.index}"
  size        = "${var.do_data_size}"
  description = "${var.account_name}-${var.do_region}${count.index}"
  count       = "${var.want_digitalocean*var.do_instance_count}"
}

resource "digitalocean_droplet" "service" {
  name       = "${var.do_region}${count.index}.${var.domain_name}"
  ssh_keys   = ["${var.do_ssh_key}"]
  region     = "${var.do_region}"
  image      = "ubuntu-16-04-x64"
  size       = "1gb"
  volume_ids = ["${element(digitalocean_volume.service.*.id,count.index)}"]
  count      = "${var.want_digitalocean*var.do_instance_count}"
}

resource "digitalocean_firewall" "service" {
  name  = "${var.account_name}-${var.do_region}"
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
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name    = "${var.do_region}${count.index}.${var.domain_name}"

  /*"*/

  type    = "A"
  ttl     = "60"
  records = ["${digitalocean_droplet.service.*.ipv4_address[count.index]}"]
  count   = "${var.want_digitalocean*var.do_instance_count}"
}
