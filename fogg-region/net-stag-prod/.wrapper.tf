module "peering_net_stag_prod" {
  source = "./module/fogg-tf/fogg-region/net-stag-prod"

  remote_bucket   = "${var.remote_bucket}"
  remote_region   = "${var.remote_region}"
  remote_key_org  = "${var.remote_key_org}"
  remote_key_net  = "${var.remote_key_net}"
  remote_key_stag = "${var.remote_key_stag}"
  remote_key_prod = "${var.remote_key_prod}"
}
