resource "digitalocean_volume" "service" {
  region      = "${element(var.do_regions,count.index)}"
  name        = "${var.account_name}-${element(var.do_regions,count.index)}${count.index}"
  size        = "${var.do_data_size}"
  description = "${var.account_name}-${element(var.do_regions,count.index)}${count.index}"
  count       = "${var.want_digitalocean*var.do_instance_count}"
}

data "template_file" "user_data_service" {
  template = "${file(var.user_data)}"

  vars {
    org = "${var.account_name}"
  }
}

resource "digitalocean_floating_ip" "service" {
  region     = "${element(var.do_regions,count.index)}"
  droplet_id = "${element(digitalocean_droplet.service.*.id,count.index)}"
  count      = "${var.want_digitalocean*var.do_instance_count}"
}

resource "digitalocean_tag" "service" {
  name  = "${var.account_name}-${element(var.do_regions,count.index)}"
  count = "${var.want_digitalocean*var.do_instance_count}"
}

resource "digitalocean_droplet" "service" {
  name       = "${element(var.do_regions,count.index)}${count.index}.${var.domain_name}"
  ssh_keys   = ["${var.do_ssh_key}"]
  region     = "${element(var.do_regions,count.index)}"
  image      = "ubuntu-16-04-x64"
  size       = "1gb"
  volume_ids = ["${element(digitalocean_volume.service.*.id,count.index)}"]
  user_data  = "${data.template_file.user_data_service.rendered}"
  tags       = ["${digitalocean_tag.service.*.id[count.index]}"]
  count      = "${var.want_digitalocean*var.do_instance_count}"
}

resource "digitalocean_firewall" "service" {
  name  = "${var.account_name}"
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
      protocol              = "udp"
      port_range            = "all"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol              = "tcp"
      port_range            = "all"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
  ]
}

resource "aws_route53_record" "do_instance" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name    = "${element(var.do_regions,count.index)}${count.index}.${var.domain_name}"

  /*"*/

  type    = "A"
  ttl     = "60"
  records = ["${digitalocean_floating_ip.service.*.ip_address[count.index]}"]
  count   = "${var.want_digitalocean*var.do_instance_count}"
}
