variable "org_bucket" {}
variable "org_key" {}
variable "org_region" {}

variable "env_key" {}
variable "app_key" {}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_partition" "current" {}

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
    bucket         = "${var.org_bucket}"
    key            = "${var.env_key}"
    region         = "${var.org_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "app" {
  backend = "s3"

  config {
    bucket         = "${var.org_bucket}"
    key            = "${var.app_key}"
    region         = "${var.org_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "aws_availability_zones" "azs" {}
data "aws_caller_identity" "current" {}

data "aws_vpc" "current" {
  id = "${data.terraform_remote_state.env.vpc_id}"
}

resource "aws_security_group" "service" {
  name        = "${local.service_name}"
  description = "Service ${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group" "cache" {
  name        = "${local.service_name}-cache"
  description = "Cache ${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${local.service_name}-cache"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-cache"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_elasticache}"
}

resource "aws_security_group" "db" {
  name        = "${local.service_name}-db"
  description = "Database ${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${local.service_name}-db"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-db"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_aurora}"
}

resource "aws_subnet" "service" {
  vpc_id = "${data.aws_vpc.current.id}"

  availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"

  cidr_block                      = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.service_bits,element(split(" ",lookup(var.service,var.service_name,"")),count.index))}"
  map_public_ip_on_launch         = "${signum(var.public_network) == 1 ? "true" : "false"}"
  assign_ipv6_address_on_creation = false

  count = "${var.want_subnets*var.az_count*(var.want_ipv6 - 1)*-1}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_subnet" "service_v6" {
  vpc_id = "${data.aws_vpc.current.id}"

  availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"

  cidr_block                      = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.service_bits,element(split(" ",lookup(var.service,var.service_name,"")),count.index))}"
  ipv6_cidr_block                 = "${cidrsubnet(data.aws_vpc.current.ipv6_cidr_block,var.ipv6_service_bits,element(split(" ",lookup(var.ipv6_service,var.service_name,"")),count.index))}"
  map_public_ip_on_launch         = "${signum(var.public_network) == 1 ? "true" : "false"}"
  assign_ipv6_address_on_creation = true

  count = "${var.want_subnets*var.az_count*var.want_ipv6}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_network_interface" "service" {
  subnet_id       = "${element(compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id)),count.index)}"
  security_groups = ["${data.terraform_remote_state.env.sg_env}", "${data.terraform_remote_state.app.app_sg}", "${aws_security_group.service.id}"]
  count           = "${var.want_subnets*var.az_count*var.want_subnets}"

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route_table" "service" {
  vpc_id = "${data.aws_vpc.current.id}"
  count  = "${var.want_routes*var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route" "service" {
  route_table_id         = "${element(aws_route_table.service.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(data.terraform_remote_state.env.nat_gateways,count.index)}"
  count                  = "${var.want_routes*var.want_subnets*var.want_nat*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route" "service_interface_nat" {
  route_table_id         = "${element(aws_route_table.service.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = "${element(data.terraform_remote_state.env.nat_interfaces,count.index)}"
  count                  = "${var.want_routes*var.want_subnets*var.want_nat_interface*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route" "service_interface_vpn" {
  route_table_id         = "${element(aws_route_table.service.*.id,count.index)}"
  destination_cidr_block = "${data.terraform_remote_state.env.vpn_cidr}"
  network_interface_id   = "${element(data.terraform_remote_state.env.vpn_interfaces,count.index)}"
  count                  = "${var.want_routes*var.want_subnets*var.want_vpn*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route" "service_v6" {
  route_table_id              = "${element(aws_route_table.service.*.id,count.index)}"
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = "${data.terraform_remote_state.env.igw_id}"
  count                       = "${var.want_routes*var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table_association" "service" {
  subnet_id      = "${element(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id),count.index)}"
  route_table_id = "${element(aws_route_table.service.*.id,count.index)}"
  count          = "${var.want_routes*var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table_association" "service_env" {
  subnet_id      = "${element(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id),count.index)}"
  route_table_id = "${element(data.terraform_remote_state.env.route_table_private,count.index)}"
  count          = "${(signum(var.want_routes)-1)*-1*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_service" {
  vpc_endpoint_id = "${data.terraform_remote_state.env.s3_endpoint_id}"
  route_table_id  = "${element(aws_route_table.service.*.id,count.index)}"
  count           = "${var.want_routes*var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_service" {
  vpc_endpoint_id = "${data.terraform_remote_state.env.dynamodb_endpoint_id}"
  route_table_id  = "${element(aws_route_table.service.*.id,count.index)}"
  count           = "${var.want_routes*var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table" "service_public" {
  vpc_id = "${data.aws_vpc.current.id}"
  count  = "${var.want_routes*var.want_subnets*var.az_count*signum(var.public_network)}"

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_route" "service_public" {
  route_table_id         = "${element(aws_route_table.service_public.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${data.terraform_remote_state.env.igw_id}"
  count                  = "${var.want_routes*var.want_subnets*var.az_count*signum(var.public_network)}"
}

resource "aws_route" "service_public_interface_vpn" {
  route_table_id         = "${element(aws_route_table.service_public.*.id,count.index)}"
  destination_cidr_block = "${data.terraform_remote_state.env.vpn_cidr}"
  network_interface_id   = "${element(data.terraform_remote_state.env.vpn_interfaces,count.index)}"
  count                  = "${var.want_routes*var.want_subnets*var.az_count*signum(var.public_network)*var.want_vpn}"
}

resource "aws_route" "service_public_v6" {
  route_table_id              = "${element(aws_route_table.service_public.*.id,count.index)}"
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = "${data.terraform_remote_state.env.igw_id}"
  count                       = "${var.want_routes*var.want_subnets*var.az_count*signum(var.public_network)}"
}

resource "aws_route_table_association" "service_public" {
  subnet_id      = "${element(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id),count.index)}"
  route_table_id = "${element(aws_route_table.service_public.*.id,count.index)}"
  count          = "${var.want_routes*var.want_subnets*var.az_count*signum(var.public_network)}"
}

resource "aws_route_table_association" "service_public_env" {
  subnet_id      = "${element(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id),count.index)}"
  route_table_id = "${element(data.terraform_remote_state.env.route_table_public,count.index)}"
  count          = "${(signum(var.want_routes)-1)*-1*var.az_count*signum(var.public_network)}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_service_public" {
  vpc_endpoint_id = "${data.terraform_remote_state.env.s3_endpoint_id}"
  route_table_id  = "${element(aws_route_table.service_public.*.id,count.index)}"
  count           = "${var.want_routes*var.want_subnets*var.az_count*signum(var.public_network)}"
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_service_public" {
  vpc_endpoint_id = "${data.terraform_remote_state.env.dynamodb_endpoint_id}"
  route_table_id  = "${element(aws_route_table.service_public.*.id,count.index)}"
  count           = "${var.want_routes*var.want_subnets*var.az_count*signum(var.public_network)}"
}

data "aws_iam_policy_document" "service" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "svc" {
  statement {
    actions = [
      "s3:*",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${data.terraform_remote_state.env.env_name}-svc/&{aws:userid}",
      "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${data.terraform_remote_state.env.env_name}-svc/&{aws:userid}/*",
    ]
  }
}

resource "aws_iam_policy" "svc" {
  name        = "${local.service_name}-svc"
  description = "${local.service_name}-svc"
  policy      = "${data.aws_iam_policy_document.svc.json}"
}

resource "aws_iam_role" "service" {
  name               = "${local.service_name}"
  assume_role_policy = "${data.aws_iam_policy_document.service.json}"
}

resource "aws_iam_role_policy_attachment" "svc" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "${aws_iam_policy.svc.arn}"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerServiceforEC2Role" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerServiceRole" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2RoleforSSM" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "AWSLambdaExecute" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "AWSCodeCommitReadOnly" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitReadOnly"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMReadOnlyAccess" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_instance_profile" "service" {
  name = "${local.service_name}"
  role = "${aws_iam_role.service.name}"
}

data "aws_iam_policy_document" "fargate" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "fargate" {
  name               = "${local.service_name}-fargate"
  assume_role_policy = "${data.aws_iam_policy_document.fargate.json}"
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  role       = "${aws_iam_role.fargate.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "template_file" "user_data_service" {
  template = "${file(var.user_data)}"

  vars {
    vpc_cidr         = "${data.aws_vpc.current.cidr_block}"
    env              = "${data.terraform_remote_state.env.env_name}"
    app              = "${data.terraform_remote_state.app.app_name}"
    service          = "${var.service_name}"
    zerotier_network = "${var.zerotier_network}"
  }
}

data "aws_ami" "ecs" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-2017.09.*-amazon-ecs-optimized"]
  }

  owners = ["amazon"]
}

data "aws_ami" "nat" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-hvm-*"]
  }

  owners = ["amazon"]
}

locals {
  vendor_ami_id = "${var.amazon_nat ? data.aws_ami.nat.image_id : data.aws_ami.ecs.image_id}"
}

module "ec2-modify-unlimited" {
  source            = "./module/fogg-tf/fogg-shell"
  region            = "${var.region}"
  command           = "./module/imma-tf/bin/tf-aws-ec2-modify-unlimited"
  resource_previous = "${join(" ",concat(aws_instance.service.*.id,list(" ")))}"
  resource_name     = "${join(" ",concat(aws_instance.service.*.id,list(" ")))}"
  mcount            = "${signum(var.instance_count)}"
}

resource "aws_route53_record" "instance_public" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${local.service_name}${count.index}.${data.terraform_remote_state.org.domain_name}"
  type    = "A"
  ttl     = "60"
  records = ["${element(aws_instance.service.*.public_ip,count.index)}"]
  count   = "${var.instance_count*var.public_network}"
}

resource "aws_instance" "service" {
  ami           = "${coalesce(element(var.ami_id,count.index),local.vendor_ami_id)}"
  instance_type = "${element(var.instance_type,count.index)}"
  count         = "${var.instance_count}"

  key_name             = "${var.key_name}"
  user_data            = "${data.template_file.user_data_service.rendered}"
  iam_instance_profile = "${local.service_name}"

  vpc_security_group_ids      = ["${concat(list(data.terraform_remote_state.env.sg_env,aws_security_group.service.id),list(data.terraform_remote_state.app.app_sg))}"]
  subnet_id                   = "${element(compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets))),count.index)}"
  associate_public_ip_address = "${var.public_network ? "true" : "false"}"

  lifecycle {
    ignore_changes = ["*"]
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "${element(var.root_volume_size,count.index)}"
  }

  ephemeral_block_device {
    device_name  = "/dev/sdb"
    virtual_name = "ephemeral0"
    no_device    = ""
  }

  ephemeral_block_device {
    device_name  = "/dev/sdc"
    virtual_name = "ephemeral1"
    no_device    = ""
  }

  ephemeral_block_device {
    device_name  = "/dev/sdd"
    virtual_name = "ephemeral2"
    no_device    = ""
  }

  ephemeral_block_device {
    device_name  = "/dev/sde"
    virtual_name = "ephemeral3"
    no_device    = ""
  }

  volume_tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_spot_fleet_request" "service" {
  iam_fleet_role      = "arn:aws:iam::${data.terraform_remote_state.org.aws_account_id}:role/aws-ec2-spot-fleet-tagging-role"
  allocation_strategy = "diversified"
  target_capacity     = "${var.instance_count_sf}"
  valid_until         = "2999-01-01T00:00:00Z"
  spot_price          = "${var.spot_price_sf}"
  count               = "${var.sf_count}"

  launch_specification {
    instance_type          = "${var.instance_type_sf}"
    ami                    = "${coalesce(element(var.ami_id,0),local.vendor_ami_id)}"
    key_name               = "${var.key_name}"
    user_data              = "${data.template_file.user_data_service.rendered}"
    vpc_security_group_ids = ["${concat(list(data.terraform_remote_state.env.sg_env,aws_security_group.service.id),list(data.terraform_remote_state.app.app_sg))}"]
    iam_instance_profile   = "${local.service_name}"
    subnet_id              = "${element(compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets))),count.index)}"
    availability_zone      = "${element(data.aws_availability_zones.azs.names,count.index)}"

    root_block_device {
      volume_type = "gp2"
      volume_size = "${element(var.root_volume_size,0)}"
    }

    tags {
      "Name"      = "${local.service_name}"
      "Env"       = "${data.terraform_remote_state.env.env_name}"
      "App"       = "${data.terraform_remote_state.app.app_name}"
      "Service"   = "${var.service_name}"
      "ManagedBy" = "spot_fleet ${local.service_name}"
    }
  }
}

resource "aws_launch_configuration" "service" {
  name_prefix          = "${local.service_name}-${element(var.asg_name,count.index)}-"
  instance_type        = "${element(var.instance_type,count.index)}"
  image_id             = "${coalesce(element(var.ami_id,count.index),local.vendor_ami_id)}"
  iam_instance_profile = "${local.service_name}"
  key_name             = "${var.key_name}"
  user_data            = "${data.template_file.user_data_service.rendered}"
  security_groups      = ["${concat(list(data.terraform_remote_state.env.sg_env,aws_security_group.service.id),list(data.terraform_remote_state.app.app_sg))}"]
  count                = "${var.asg_count}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "${element(var.root_volume_size,count.index)}"
  }

  ephemeral_block_device {
    device_name  = "/dev/sdb"
    virtual_name = "ephemeral0"
  }

  ephemeral_block_device {
    device_name  = "/dev/sdc"
    virtual_name = "ephemeral1"
  }

  ephemeral_block_device {
    device_name  = "/dev/sdd"
    virtual_name = "ephemeral2"
  }

  ephemeral_block_device {
    device_name  = "/dev/sde"
    virtual_name = "ephemeral3"
  }
}

locals {
  ses_domain = "${data.terraform_remote_state.app.app_name}-${var.service_name}.${data.terraform_remote_state.env.private_zone_name}"
}

resource "aws_ses_domain_identity" "service" {
  provider = "aws.us_east_1"
  domain   = "${local.ses_domain}"
}

resource "aws_ses_receipt_rule" "s3" {
  provider      = "aws.us_east_1"
  name          = "${local.ses_domain}"
  rule_set_name = "${data.terraform_remote_state.org.domain_name}"
  recipients    = ["${local.ses_domain}"]
  enabled       = true
  scan_enabled  = true
  tls_policy    = "Require"

  s3_action {
    bucket_name       = "${data.terraform_remote_state.env.s3_env_ses}"
    object_key_prefix = "${local.ses_domain}"
    position          = 1
  }
}

resource "aws_ses_domain_dkim" "service" {
  provider = "aws.us_east_1"
  domain   = "${aws_ses_domain_identity.service.domain}"
}

resource "aws_route53_record" "verify_dkim" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${element(aws_ses_domain_dkim.service.dkim_tokens, count.index)}._domainkey.${local.ses_domain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.service.dkim_tokens, count.index)}.dkim.amazonses.com"]
  count   = 3
}

resource "aws_route53_record" "verify_ses" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "_amazonses.${local.ses_domain}"
  type    = "TXT"
  ttl     = "60"
  records = ["${aws_ses_domain_identity.service.verification_token}"]
}

resource "aws_route53_record" "mx" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${local.ses_domain}"
  type    = "MX"
  ttl     = "60"
  records = ["10 inbound-smtp.us-east-1.amazonaws.com"]
}

resource "aws_sns_topic" "service" {
  name  = "${local.service_name}-${element(var.asg_name,count.index)}"
  count = "${var.asg_count}"
}

resource "aws_sqs_queue" "service" {
  name                        = "${local.service_name}-${element(var.asg_name,count.index)}${var.want_fifo ? ".fifo" : ""}"
  policy                      = "${element(data.aws_iam_policy_document.service-sns-sqs.*.json,count.index)}"
  count                       = "${var.asg_count}"
  fifo_queue                  = "${var.want_fifo ? true : false}"
  content_based_deduplication = "${var.want_fifo ? true : false}"

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

data "aws_iam_policy_document" "service-sns-sqs" {
  statement {
    actions = [
      "sqs:SendMessage",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:sqs:${var.region}:${data.terraform_remote_state.org.aws_account_id}:${local.service_name}-${element(var.asg_name,count.index)}.fifo",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        "${element(aws_sns_topic.service.*.arn,count.index)}",
      ]
    }
  }

  count = "${var.asg_count}"
}

resource "aws_sns_topic_subscription" "service" {
  topic_arn = "${element(aws_sns_topic.service.*.arn,count.index)}"
  endpoint  = "${element(aws_sqs_queue.service.*.arn,count.index)}"
  protocol  = "sqs"
  count     = "${var.asg_count}"
}

resource "aws_ecs_cluster" "service" {
  name = "${local.service_name}"
}

resource "aws_ecs_task_definition" "ex_dynamic" {
  family       = "${local.service_name}-ex_dynamic"
  network_mode = "bridge"

  container_definitions = <<DEFINITION
[
  {
    "cpu": 64,
    "essential": true,
    "image": "crccheck/hello-world",
    "memory": 64,
    "name": "httpd-a",
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 0
      }
    ]
  },
  {
    "cpu": 64,
    "essential": true,
    "image": "crccheck/hello-world",
    "memory": 64,
    "name": "httpd-b",
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 0
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "ex_dynamic" {
  name            = "${local.service_name}-ex_dynamic"
  cluster         = "${aws_ecs_cluster.service.id}"
  task_definition = "${aws_ecs_task_definition.ex_dynamic.arn}"
  desired_count   = "1"

  placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  placement_constraints {
    type = "distinctInstance"
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_ecs_task_definition" "ex_host" {
  family       = "${local.service_name}-ex_host"
  network_mode = "host"

  container_definitions = <<DEFINITION
[
  {
    "cpu": 64,
    "environment": [],
    "essential": true,
    "image": "crccheck/hello-world",
    "memory": 64,
    "mountPoints": [],
    "name": "httpd",
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000,
        "protocol": "tcp"
      }
    ],
    "volumesFrom": []
  }
]
DEFINITION
}

resource "aws_ecs_service" "ex_host" {
  name            = "${local.service_name}-ex_host"
  cluster         = "${aws_ecs_cluster.service.id}"
  task_definition = "${aws_ecs_task_definition.ex_host.arn}"
  desired_count   = "1"

  placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  placement_constraints {
    type = "distinctInstance"
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_ecs_task_definition" "ex_vpc" {
  family       = "${local.service_name}-ex_vpc"
  network_mode = "awsvpc"

  container_definitions = <<DEFINITION
[
  {
    "cpu": 64,
    "environment": [],
    "essential": true,
    "image": "crccheck/hello-world",
    "memory": 64,
    "mountPoints": [],
    "name": "httpd",
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000,
        "protocol": "tcp"
      }
    ],
    "volumesFrom": []
  }
]
DEFINITION
}

resource "aws_ecs_service" "ex_vpc" {
  name            = "${local.service_name}-ex_vpc"
  cluster         = "${aws_ecs_cluster.service.id}"
  task_definition = "${aws_ecs_task_definition.ex_vpc.arn}"
  desired_count   = "1"

  network_configuration {
    subnets         = ["${compact(concat(formatlist(var.public_lb ? "%[1]s" : "%[2]s",data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets)))}"]
    security_groups = ["${data.terraform_remote_state.env.sg_env}", "${data.terraform_remote_state.app.app_sg}", "${aws_security_group.app.id}"]
  }

  placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  placement_constraints {
    type = "distinctInstance"
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_ecs_task_definition" "ex_fargate" {
  family                   = "${local.service_name}-ex_fargate"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.fargate.arn}"

  container_definitions = <<DEFINITION
[
  {
    "cpu": 64,
    "environment": [],
    "essential": true,
    "image": "crccheck/hello-world",
    "memory": 64,
    "mountPoints": [],
    "name": "httpd",
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000,
        "protocol": "tcp"
      }
    ],
    "volumesFrom": []
  }
]
DEFINITION
}

resource "aws_ecs_service" "ex_fargate" {
  name            = "${local.service_name}-ex_fargate"
  cluster         = "${aws_ecs_cluster.service.id}"
  task_definition = "${aws_ecs_task_definition.ex_fargate.arn}"
  launch_type     = "FARGATE"
  desired_count   = "0"

  network_configuration {
    subnets         = ["${compact(concat(formatlist(var.public_lb ? "%[1]s" : "%[2]s",data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets)))}"]
    security_groups = ["${data.terraform_remote_state.env.sg_env}", "${data.terraform_remote_state.app.app_sg}", "${aws_security_group.app.id}"]
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_autoscaling_group" "service" {
  name                 = "${local.service_name}-${element(var.asg_name,count.index)}"
  launch_configuration = "${element(aws_launch_configuration.service.*.name,count.index)}"
  vpc_zone_identifier  = ["${compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets)))}"]
  min_size             = "${element(var.min_size,count.index)}"
  max_size             = "${element(var.max_size,count.index)}"
  termination_policies = ["${var.termination_policies}"]
  target_group_arns    = ["${compact(list(element(concat(aws_lb_target_group.net.*.arn,list("","")),count.index)))}"]
  count                = "${var.asg_count}"

  tag {
    key                 = "Name"
    value               = "${local.service_name}-${element(var.asg_name,count.index)}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = "${data.terraform_remote_state.env.env_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "App"
    value               = "${data.terraform_remote_state.app.app_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "${var.service_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Patch Group"
    value               = "${local.service_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "autoscaling ${local.service_name}-${element(var.asg_name,count.index)}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Color"
    value               = "${element(var.asg_name,count.index)}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_notification" "service" {
  topic_arn = "${element(aws_sns_topic.service.*.arn,count.index)}"

  group_names = [
    "${element(aws_autoscaling_group.service.*.name,count.index)}",
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  count = "${var.asg_count}"
}

module "efs" {
  source   = "./module/fogg-tf/fogg-efs"
  efs_name = "${local.service_name}"
  vpc_id   = "${data.terraform_remote_state.env.vpc_id}"
  env_name = "${data.terraform_remote_state.env.env_name}"
  subnets  = ["${compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets)))}"]
  az_count = "${var.az_count}"
  want_efs = "${var.want_efs}"
}

resource "aws_security_group_rule" "allow_service_mount" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.service.id}"
  security_group_id        = "${module.efs.efs_sg}"
  count                    = "${var.want_efs}"
}

resource "aws_route53_record" "efs" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-efs.${data.terraform_remote_state.env.private_zone_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${element(module.efs.efs_dns_names,count.index)}"]
  count   = "${var.want_efs}"
}

resource "aws_security_group_rule" "allow_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.service.id}"
  security_group_id        = "${aws_security_group.cache.id}"
  count                    = "${var.want_elasticache}"
}

resource "aws_route53_record" "cache" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-cache.${data.terraform_remote_state.env.private_zone_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${aws_elasticache_replication_group.service.configuration_endpoint_address}"]
  count   = "${var.want_elasticache}"
}

resource "aws_route53_record" "db" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-db.${data.terraform_remote_state.env.private_zone_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${aws_rds_cluster.service.endpoint}"]
  count   = "${var.want_aurora}"
}

resource "aws_route53_record" "db_ro" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-db-ro.${data.terraform_remote_state.env.private_zone_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${aws_rds_cluster.service.reader_endpoint}"]
  count   = "${var.want_aurora}"
}

resource "aws_kms_key" "service" {
  description         = "Service ${var.service_name}"
  enable_key_rotation = true

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_kms}"
}

resource "aws_kms_alias" "service" {
  name          = "alias/${local.service_name}"
  target_key_id = "${var.want_kms ? join(" ",aws_kms_key.service.*.key_id) : data.terraform_remote_state.env.kms_key_id}"
}

resource "aws_codecommit_repository" "service" {
  repository_name = "${local.service_name}"
  description     = "Repo for ${local.service_name} service"
}

resource "aws_codecommit_trigger" "service" {
  depends_on      = ["aws_codecommit_repository.service"]
  repository_name = "${local.service_name}"

  trigger {
    name            = "all"
    events          = ["all"]
    destination_arn = "${aws_sns_topic.codecommit.arn}"
  }
}

resource "aws_codedeploy_app" "service" {
  name = "${local.service_name}"
}

resource "aws_sns_topic" "codedeploy" {
  name = "${local.service_name}-codedeploy"
}

resource "aws_iam_role" "codedeploy" {
  name = "${local.service_name}-codedeploy"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codedeploy" {
  name = "${local.service_name}-codedeploy"
  role = "${aws_iam_role.codedeploy.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:DeleteLifecycleHook",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLifecycleHooks",
        "autoscaling:PutLifecycleHook",
        "autoscaling:RecordLifecycleActionHeartbeat",
        "codedeploy:*",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "tag:GetTags",
        "tag:GetResources",
        "sns:Publish"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codedeploy_deployment_group" "service" {
  app_name              = "${aws_codedeploy_app.service.name}"
  deployment_group_name = "${local.service_name}"
  service_role_arn      = "${aws_iam_role.codedeploy.arn}"

  ec2_tag_filter {
    type  = "KEY_AND_VALUE"
    key   = "Name"
    value = "${local.service_name}"
  }

  trigger_configuration {
    trigger_events     = ["DeploymentStart", "DeploymentSuccess", "DeploymentFailure", "DeploymentStop", "DeploymentRollback", "InstanceStart", "InstanceSuccess", "InstanceFailure"]
    trigger_name       = "${local.service_name}"
    trigger_target_arn = "${aws_sns_topic.codedeploy.arn}"
  }
}

resource "aws_iam_role" "codebuild" {
  name = "${local.service_name}-codebuild"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "codebuild" {
  name        = "${local.service_name}-codebuild"
  description = "${local.service_name}-codebuild"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "codebuild" {
  name       = "${local.service_name}-codebuild"
  policy_arn = "${aws_iam_policy.codebuild.arn}"
  roles      = ["${aws_iam_role.codebuild.id}"]
}

resource "aws_ecr_repository" "service" {
  name = "${local.service_name}"
}

resource "aws_codebuild_project" "foo" {
  name          = "${local.service_name}"
  description   = "${local.service_name}"
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild.arn}"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "${aws_ecr_repository.service.repository_url}:build"
    type         = "LINUX_CONTAINER"

    environment_variable {
      "name"  = "test"
      "value" = "ing"
    }
  }

  source {
    type     = "CODECOMMIT"
    location = "${aws_codecommit_repository.service.clone_url_http}"
  }

  tags {
    "Name"      = "${local.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_sns_topic" "codecommit" {
  name = "${local.service_name}-codecommit"
}

resource "aws_db_subnet_group" "service" {
  name       = "${local.service_name}"
  subnet_ids = ["${compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets)))}"]

  tags {
    "Name"      = "${local.service_name}-db-subnet"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-db"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_aurora}"
}

resource "aws_rds_cluster_parameter_group" "service" {
  name        = "${local.service_name}"
  family      = "aurora5.6"
  description = "${local.service_name}"

  tags {
    "Name"      = "${local.service_name}-db-cluster-parameter"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-db"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_aurora}"
}

resource "aws_db_parameter_group" "service" {
  name_prefix = "${local.service_name}-"
  family      = "aurora5.6"
  description = "${local.service_name}"

  tags {
    "Name"      = "${local.service_name}-db-parameter"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-db"
    "ManagedBy" = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }

  count = "${var.want_aurora}"
}

resource "aws_rds_cluster_instance" "service" {
  identifier              = "${local.service_name}-${count.index}"
  cluster_identifier      = "${aws_rds_cluster.service.id}"
  instance_class          = "db.t2.small"
  db_subnet_group_name    = "${aws_db_subnet_group.service.name}"
  db_parameter_group_name = "${aws_db_parameter_group.service.name}"

  tags {
    "Name"      = "${local.service_name}-db-${count.index}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-db"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_aurora*var.aurora_instances}"
}

resource "aws_rds_cluster" "service" {
  cluster_identifier              = "${local.service_name}"
  database_name                   = "meh"
  master_username                 = "meh"
  master_password                 = "${local.service_name}"
  vpc_security_group_ids          = ["${data.terraform_remote_state.env.sg_env}", "${data.terraform_remote_state.app.app_sg}", "${aws_security_group.db.id}"]
  db_subnet_group_name            = "${aws_db_subnet_group.service.name}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.service.name}"

  count = "${var.want_aurora}"
}

resource "aws_elasticache_replication_group" "service" {
  replication_group_id          = "${local.service_name}"
  replication_group_description = "${local.service_name}"
  engine                        = "redis"
  engine_version                = "3.2.10"
  node_type                     = "cache.t2.micro"
  port                          = 6379
  parameter_group_name          = "default.redis3.2.cluster.on"
  automatic_failover_enabled    = true
  subnet_group_name             = "${aws_elasticache_subnet_group.service.name}"
  security_group_ids            = ["${data.terraform_remote_state.env.sg_env}", "${data.terraform_remote_state.app.app_sg}", "${aws_security_group.cache.id}"]

  automatic_failover_enabled = true

  cluster_mode {
    replicas_per_node_group = 0
    num_node_groups         = 1
  }

  tags {
    "Name"      = "${local.service_name}-cache"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-cache"
    "ManagedBy" = "terraform"
  }

  lifecycle {
    ignore_changes = ["name"]
  }

  count = "${var.want_elasticache}"
}

resource "aws_elasticache_subnet_group" "service" {
  name       = "${local.service_name}"
  subnet_ids = ["${compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets)))}"]

  count = "${var.want_elasticache}"
}

locals {
  service_name     = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  apig_rest_id     = "${data.terraform_remote_state.env.api_gateway}"
  apig_resource_id = "${data.terraform_remote_state.env.api_gateway_resource}"
  apig_domain_name = "${data.terraform_remote_state.env.private_zone_name}"
  apig_vpc_link_id = "${module.apig-vpc-link.out1}"
}

module "apig-vpc-link" {
  source            = "./module/fogg-tf/fogg-shell-r"
  region            = "${var.region}"
  command           = "./module/imma-tf/bin/tf-aws-apig-vpc-link"
  resource_previous = "${local.service_name}-live"
  resource_name     = "${local.service_name}-live"
  arg1              = "${element(concat(aws_lb.net.*.arn,list("")),0)}"
  mcount            = "${var.want_vpc_link*var.want_nlb}"
}

resource "aws_api_gateway_method" "apig-vpc-link" {
  rest_api_id   = "${local.apig_rest_id}"
  resource_id   = "${local.apig_resource_id}"
  http_method   = "POST"
  authorization = "NONE"
  count         = "${var.want_vpc_link*var.want_nlb}"
}

module "apig-vpc-link-integration" {
  source            = "./module/fogg-tf/fogg-shell"
  region            = "${var.region}"
  command           = "./module/imma-tf/bin/tf-aws-apig-vpc-link-integration"
  resource_previous = "${local.service_name}-live"
  resource_name     = "${local.service_name}-live"
  arg1              = "${local.apig_rest_id}"
  arg2              = "${local.apig_resource_id}"
  arg3              = "https://${local.apig_domain_name}"
  arg4              = "${element(concat(aws_api_gateway_method.apig-vpc-link.*.id,list("")),0)}"
  mcount            = "${var.want_vpc_link*var.want_nlb}"
}

resource "null_resource" "apig-vpc-link-integration-deployment" {
  triggers {
    integration_id = "${module.apig-vpc-link-integration.id}"
  }
}

module "apig-vpc-link-deployment" {
  source            = "./module/fogg-tf/fogg-shell"
  region            = "${var.region}"
  command           = "./module/imma-tf/bin/tf-aws-apig-vpc-link-deployment"
  resource_previous = "${lookup(null_resource.apig-vpc-link-integration-deployment.triggers,"integration_id")}"
  resource_name     = "${lookup(null_resource.apig-vpc-link-integration-deployment.triggers,"integration_id")}"
  arg1              = "${local.apig_rest_id}"
  arg2              = "live"
  arg3              = "${local.apig_vpc_link_id}"
  mcount            = "${var.want_vpc_link*var.want_nlb}"
}

resource "aws_lb" "net" {
  name               = "${local.service_name}-${element(var.asg_name,count.index)}"
  load_balancer_type = "network"
  internal           = "${var.public_lb == 0 ? true : false}"

  subnets = ["${compact(concat(formatlist(var.public_lb ? "%[1]s" : "%[2]s",data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets)))}"]

  tags {
    Name      = "${local.service_name}-${element(var.asg_name,count.index)}"
    Env       = "${data.terraform_remote_state.env.env_name}"
    App       = "${data.terraform_remote_state.app.app_name}"
    Service   = "${var.service_name}"
    ManagedBy = "terraform"
    Color     = "${element(var.asg_name,count.index)}"
  }

  count = "${var.want_nlb*var.asg_count}"
}

resource "aws_lb" "app" {
  name               = "${local.service_name}-${element(var.asg_name,count.index)}"
  load_balancer_type = "application"
  internal           = "${var.public_lb == 0 ? true : false}"

  subnets = ["${compact(concat(formatlist(var.public_lb ? "%[1]s" : "%[2]s",data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets)))}"]

  security_groups = ["${data.terraform_remote_state.env.sg_env}", "${data.terraform_remote_state.app.app_sg}", "${aws_security_group.app.id}"]

  tags {
    Name      = "${local.service_name}-${element(var.asg_name,count.index)}"
    Env       = "${data.terraform_remote_state.env.env_name}"
    App       = "${data.terraform_remote_state.app.app_name}"
    Service   = "${var.service_name}"
    ManagedBy = "terraform"
    Color     = "${element(var.asg_name,count.index)}"
  }

  count = "${var.want_alb*var.asg_count}"
}

resource "aws_security_group" "app" {
  name        = "${local.service_name}-lb"
  description = "Service ${data.terraform_remote_state.app.app_name}-${var.service_name}-lb"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${local.service_name}-lb"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-lb"
    "ManagedBy" = "terraform"
  }
}

resource "aws_lb_listener" "net" {
  load_balancer_arn = "${element(aws_lb.net.*.arn,count.index)}"
  port              = 443
  protocol          = "TCP"

  default_action {
    target_group_arn = "${element(aws_lb_target_group.net.*.arn,count.index)}"
    type             = "forward"
  }

  count = "${var.want_nlb*var.asg_count}"
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = "${element(aws_lb.app.*.arn,count.index)}"
  port              = 443
  protocol          = "HTTPS"

  default_action {
    target_group_arn = "${element(aws_lb_target_group.app.*.arn,count.index)}"
    type             = "forward"
  }

  certificate_arn = "${data.terraform_remote_state.env.env_cert}"

  ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"

  count = "${var.want_alb*var.asg_count}"
}

resource "aws_lb_target_group" "net" {
  name     = "${local.service_name}-${element(var.asg_name,count.index)}"
  port     = 443
  protocol = "TCP"
  vpc_id   = "${data.aws_vpc.current.id}"
  count    = "${var.want_nlb*var.asg_count}"
}

resource "aws_lb_target_group" "app" {
  name     = "${local.service_name}-${element(var.asg_name,count.index)}"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${data.aws_vpc.current.id}"
  count    = "${var.want_alb*var.asg_count}"
}

resource "aws_route53_record" "net" {
  zone_id = "${var.public_lb ? data.terraform_remote_state.org.public_zone_id : data.terraform_remote_state.env.private_zone_id}"
  name    = "${var.public_lb ? "${local.service_name}-${element(var.asg_name,count.index)}.${data.terraform_remote_state.org.domain_name}" : "${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}.${data.terraform_remote_state.env.private_zone_name}"}"
  type    = "A"

  alias {
    name                   = "${element(concat(aws_lb.net.*.dns_name),count.index)}"
    zone_id                = "${element(concat(aws_lb.net.*.zone_id),count.index)}"
    evaluate_target_health = false
  }

  count = "${var.asg_count*signum(var.want_nlb)}"
}

resource "aws_route53_record" "app" {
  zone_id = "${var.public_lb ? data.terraform_remote_state.org.public_zone_id : data.terraform_remote_state.env.private_zone_id}"
  name    = "${var.public_lb ? "${local.service_name}-${element(var.asg_name,count.index)}.${data.terraform_remote_state.org.domain_name}" : "${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}.${data.terraform_remote_state.env.private_zone_name}"}"
  type    = "A"

  alias {
    name                   = "${element(concat(aws_lb.app.*.dns_name),count.index)}"
    zone_id                = "${element(concat(aws_lb.app.*.zone_id),count.index)}"
    evaluate_target_health = false
  }

  count = "${var.asg_count*signum(var.want_alb)}"
}

resource "aws_iam_role" "batch" {
  name = "${local.service_name}-batch"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "batch.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSBatchServiceRole" {
  role       = "${aws_iam_role.batch.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_batch_compute_environment" "batch" {
  compute_environment_name = "${local.service_name}"
  service_role             = "${aws_iam_role.batch.arn}"
  type                     = "UNMANAGED"
  depends_on               = ["aws_iam_role_policy_attachment.AWSBatchServiceRole"]
}

resource "aws_batch_job_queue" "batch" {
  name                 = "${local.service_name}"
  state                = "ENABLED"
  priority             = 1
  compute_environments = ["${aws_batch_compute_environment.batch.arn}"]
}

resource "aws_ssm_parameter" "fogg_svc" {
  name      = "${local.service_name}.fogg_svc"
  type      = "String"
  value     = "${var.service_name}"
  overwrite = true
}

resource "aws_ssm_parameter" "fogg_svc_sg" {
  name      = "${local.service_name}.fogg_svc_sg"
  type      = "String"
  value     = "${aws_security_group.service.id}"
  overwrite = true
}

resource "aws_ssm_parameter" "fogg_svc_subnets" {
  name      = "${local.service_name}.fogg_svc_subnets"
  type      = "String"
  value     = "${join(" ",compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id)))}"
  overwrite = true
}

resource "aws_ssm_parameter" "fogg_svc_ssh_key" {
  name      = "${local.service_name}.fogg_svc_ssh_key"
  type      = "String"
  value     = "${var.key_name}"
  overwrite = true
}

resource "aws_ssm_parameter" "fogg_svc_ami" {
  name      = "${local.service_name}.fogg_svc_ami"
  type      = "String"
  value     = "${coalesce(element(var.ami_id,count.index),local.vendor_ami_id)}"
  overwrite = true
}

resource "aws_ssm_parameter" "fogg_svc_iam_profile" {
  name      = "${local.service_name}.fogg_svc_iam_profile"
  type      = "String"
  value     = "${local.service_name}"
  overwrite = true
}

resource "aws_service_discovery_private_dns_namespace" "env" {
  name  = "${local.service_name}.${data.terraform_remote_state.org.domain_name}"
  vpc   = "${data.terraform_remote_state.env.vpc_id}"
  count = "${var.want_sd}"
}
