variable "global_bucket" {}
variable "global_key" {}
variable "global_region" {}

variable "env_bucket" {}
variable "env_key" {}
variable "env_region" {}

variable "app_bucket" {}
variable "app_key" {}
variable "app_region" {}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket         = "${var.global_bucket}"
    key            = "${var.global_key}"
    region         = "${var.global_region}"
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

data "aws_availability_zones" "azs" {}
data "aws_caller_identity" "current" {}

data "aws_vpc" "current" {
  id = "${data.terraform_remote_state.env.vpc_id}"
}

data "aws_acm_certificate" "env" {
  domain   = "*.${data.terraform_remote_state.org.domain_name}"
  statuses = ["ISSUED", "PENDING_VALIDATION"]
}

resource "aws_security_group" "service" {
  name        = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  description = "Service ${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group" "cache" {
  name        = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-cache"
  description = "Cache ${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-cache"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-cache"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_elasticache}"
}

resource "aws_subnet" "service" {
  vpc_id = "${data.aws_vpc.current.id}"

  availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"

  cidr_block              = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.service_bits,element(split(" ",lookup(var.service,var.service_name,"")),count.index))}"
  map_public_ip_on_launch = "${signum(var.public_network) == 1 ? "true" : "false"}"

  count = "${var.want_subnets*var.az_count*(var.want_ipv6 - 1)*-1}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_subnet" "service_v6" {
  vpc_id = "${data.aws_vpc.current.id}"

  availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"

  cidr_block              = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.service_bits,element(split(" ",lookup(var.service,var.service_name,"")),count.index))}"
  map_public_ip_on_launch = "${signum(var.public_network) == 1 ? "true" : "false"}"

  count = "${var.want_subnets*var.az_count*var.want_ipv6}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
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
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route_table" "service" {
  vpc_id = "${data.aws_vpc.current.id}"
  count  = "${var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
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
  count                  = "${var.want_subnets*var.want_nat*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route" "service_interface_nat" {
  route_table_id         = "${element(aws_route_table.service.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = "${element(data.terraform_remote_state.env.nat_interfaces,count.index)}"
  count                  = "${var.want_subnets*var.want_nat_interface*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route" "service_interface_vpn" {
  route_table_id         = "${element(aws_route_table.service.*.id,count.index)}"
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = "${element(data.terraform_remote_state.env.vpn_interfaces,count.index)}"
  count                  = "${var.want_subnets*var.want_vpn*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route" "service_v6" {
  route_table_id              = "${element(aws_route_table.service.*.id,count.index)}"
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = "${data.terraform_remote_state.env.egw_gateway}"
  count                       = "${var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table_association" "service" {
  subnet_id      = "${element(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id),count.index)}"
  route_table_id = "${element(aws_route_table.service.*.id,count.index)}"
  count          = "${var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_service" {
  vpc_endpoint_id = "${data.terraform_remote_state.env.s3_endpoint_id}"
  route_table_id  = "${element(aws_route_table.service.*.id,count.index)}"
  count           = "${var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_service" {
  vpc_endpoint_id = "${data.terraform_remote_state.env.dynamodb_endpoint_id}"
  route_table_id  = "${element(aws_route_table.service.*.id,count.index)}"
  count           = "${var.want_subnets*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table" "service_public" {
  vpc_id = "${data.aws_vpc.current.id}"
  count  = "${var.want_subnets*var.az_count*signum(var.public_network)}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
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
  count                  = "${var.want_subnets*var.az_count*signum(var.public_network)}"
}

resource "aws_route" "service_public_interface_vpn" {
  route_table_id         = "${element(aws_route_table.service_public.*.id,count.index)}"
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = "${element(data.terraform_remote_state.env.vpn_interfaces,count.index)}"
  count                  = "${var.want_subnets*var.az_count*signum(var.public_network)*var.want_vpn}"
}

resource "aws_route" "service_public_v6" {
  route_table_id              = "${element(aws_route_table.service_public.*.id,count.index)}"
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = "${data.terraform_remote_state.env.egw_gateway}"
  count                       = "${var.want_subnets*var.az_count*signum(var.public_network)}"
}

resource "aws_route_table_association" "service_public" {
  subnet_id      = "${element(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id),count.index)}"
  route_table_id = "${element(aws_route_table.service_public.*.id,count.index)}"
  count          = "${var.want_subnets*var.az_count*signum(var.public_network)}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_service_public" {
  vpc_endpoint_id = "${data.terraform_remote_state.env.s3_endpoint_id}"
  route_table_id  = "${element(aws_route_table.service_public.*.id,count.index)}"
  count           = "${var.want_subnets*var.az_count*signum(var.public_network)}"
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_service_public" {
  vpc_endpoint_id = "${data.terraform_remote_state.env.dynamodb_endpoint_id}"
  route_table_id  = "${element(aws_route_table.service_public.*.id,count.index)}"
  count           = "${var.want_subnets*var.az_count*signum(var.public_network)}"
}

data "aws_iam_policy_document" "service" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "ecs.amazonaws.com", "lambda.amazonaws.com", "apigateway.amazonaws.com"]
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

resource "aws_iam_role" "service" {
  name               = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  assume_role_policy = "${data.aws_iam_policy_document.service.json}"
}

resource "aws_iam_role_policy_attachment" "lambda_exec" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs-container" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role_policy_attachment" "cc_ro" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm-agent" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "ssm-ro" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_instance_profile" "service" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  role = "${aws_iam_role.service.name}"
}

data "template_file" "user_data_service" {
  template = "${file(var.user_data)}"

  vars {
    vpc_cidr = "${data.aws_vpc.current.cidr_block}"
    env      = "${data.terraform_remote_state.env.env_name}"
    app      = "${data.terraform_remote_state.app.app_name}"
    service  = "${var.service_name}"
  }
}

data "aws_ami" "block" {
  most_recent = true

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:Block"
    values = ["${var.block}-*"]
  }

  owners = ["self"]
}

data "aws_ami" "amazon" {
  most_recent = true

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-2017.*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }

  owners = ["137112412989"]
}

locals {
  vendor_ami_id = "${var.amazon_linux ? data.aws_ami.amazon.image_id : data.aws_ami.block.image_id}"
}

resource "aws_instance" "service" {
  ami           = "${coalesce(element(var.ami_id,count.index),local.vendor_ami_id)}"
  instance_type = "${element(var.instance_type,count.index)}"
  count         = "${var.instance_count}"

  key_name             = "${var.key_name}"
  user_data            = "${data.template_file.user_data_service.rendered}"
  iam_instance_profile = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"

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
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
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
    iam_instance_profile   = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    subnet_id              = "${element(compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets))),count.index)}"
    availability_zone      = "${element(data.aws_availability_zones.azs.names,count.index)}"

    root_block_device {
      volume_type = "gp2"
      volume_size = "${element(var.root_volume_size,0)}"
    }
  }
}

resource "aws_launch_configuration" "service" {
  name_prefix          = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}-"
  instance_type        = "${element(var.instance_type,count.index)}"
  image_id             = "${coalesce(element(var.ami_id,count.index),local.vendor_ami_id)}"
  iam_instance_profile = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
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
  records = ["10 inbound-smtp.${var.env_region}.amazonaws.com"]
}

resource "aws_sns_topic" "service" {
  name  = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  count = "${var.asg_count}"
}

resource "aws_sqs_queue" "service" {
  name                        = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}.fifo"
  policy                      = "${element(data.aws_iam_policy_document.service-sns-sqs.*.json,count.index)}"
  count                       = "${var.asg_count}"
  fifo_queue                  = true
  content_based_deduplication = true
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
      "arn:aws:sqs:${var.env_region}:${data.terraform_remote_state.org.aws_account_id}:${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}.fifo",
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
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
}

resource "aws_autoscaling_group" "service" {
  name                 = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  launch_configuration = "${element(aws_launch_configuration.service.*.name,count.index)}"
  vpc_zone_identifier  = ["${compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets)))}"]
  min_size             = "${element(var.min_size,count.index)}"
  max_size             = "${element(var.max_size,count.index)}"
  termination_policies = ["${var.termination_policies}"]
  target_group_arns    = ["${compact(list(element(concat(aws_lb_target_group.net.*.arn,list("","")),count.index)))}"]
  count                = "${var.asg_count}"

  tag {
    key                 = "Name"
    value               = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
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
    key                 = "ManagedBy"
    value               = "asg ${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
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
  source   = "./module/fogg-efs"
  efs_name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
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
  records = ["${aws_elasticache_cluster.service.cache_nodes.0.address}"]
  count   = "${var.want_elasticache}"
}

resource "aws_kms_key" "service" {
  description         = "Service ${var.service_name}"
  enable_key_rotation = true

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_kms}"
}

resource "aws_kms_alias" "service" {
  name          = "alias/${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  target_key_id = "${var.want_kms ? join(" ",aws_kms_key.service.*.key_id) : data.terraform_remote_state.env.kms_key_id}"
}

resource "aws_codecommit_repository" "service" {
  repository_name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  description     = "Repo for ${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name} service"
}

resource "aws_codedeploy_app" "service" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
}

resource "packet_project" "service" {
  name  = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  count = "${var.want_packet}"
}

resource "packet_device" "service" {
  hostname         = "packet-${data.terraform_remote_state.app.app_name}-${var.service_name}${count.index+1}.${data.terraform_remote_state.env.private_zone_name}" /*"*/
  project_id       = "${packet_project.service.id}"
  facility         = "${var.packet_facility}"
  plan             = "${var.packet_plan}"
  billing_cycle    = "hourly"
  operating_system = "${var.packet_operating_system}"
  count            = "${var.want_packet*var.packet_instance_count}"
}

resource "packet_volume" "service" {
  project_id    = "${packet_project.service.id}"
  facility      = "${var.packet_facility}"
  plan          = "storage_1"
  billing_cycle = "hourly"
  size          = "40"
  count         = "${var.want_packet}"
}

resource "aws_route53_record" "packet_instance" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "packet-${data.terraform_remote_state.app.app_name}-${var.service_name}${count.index+1}.${data.terraform_remote_state.env.private_zone_name}" /*"*/
  type    = "A"
  ttl     = "60"
  records = ["${element(packet_device.service.*.network.0.address,count.index)}"]
  count   = "${var.want_packet*var.packet_instance_count}"
}

resource "digitalocean_volume" "service" {
  name   = "do-${data.terraform_remote_state.app.app_name}-${var.service_name}${count.index+1}-${data.terraform_remote_state.env.env_name}" /*"*/
  region = "${var.do_region}"
  size   = 40
  count  = "${var.want_digitalocean}"
}

resource "digitalocean_droplet" "service" {
  name       = "do-${data.terraform_remote_state.app.app_name}-${var.service_name}${count.index+1}.${data.terraform_remote_state.env.private_zone_name}" /*"*/
  ssh_keys   = ["${data.terraform_remote_state.env.do_ssh_key}"]
  region     = "${var.do_region}"
  image      = "ubuntu-16-04-x64"
  size       = "1gb"
  volume_ids = ["${compact(list(count.index == 0 ? digitalocean_volume.service.id : ""))}"]
  count      = "${var.want_digitalocean*var.do_instance_count}"
}

resource "digitalocean_firewall" "service" {
  name  = "${data.terraform_remote_state.app.app_name}-${var.service_name}${count.index+1}.${data.terraform_remote_state.env.private_zone_name}" /*"*/
  count = "${signum(var.want_digitalocean*var.do_instance_count)}"

  droplet_ids = ["${digitalocean_droplet.service.*.id}"]

  inbound_rule = [
    {
      protocol         = "tcp"
      port_range       = "22"
      source_addresses = ["0.0.0.0/24"]
    },
  ]

  outbound_rule = [
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
    {
      protocol              = "icmp"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
  ]
}

resource "aws_route53_record" "do_instance" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"

  name = "do-${data.terraform_remote_state.app.app_name}-${var.service_name}${count.index+1}.${data.terraform_remote_state.env.private_zone_name}"

  /*"*/

  type    = "A"
  ttl     = "60"
  records = ["${digitalocean_droplet.service.*.ipv4_address[count.index]}"]
  count   = "${var.want_digitalocean*var.do_instance_count}"
}

data "aws_iam_policy_document" "fn" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fn" {
  name               = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-fn"
  assume_role_policy = "${data.aws_iam_policy_document.fn.json}"
}

locals {
  deployment_zip  = ["${split("/","${path.module}/dist/deployment.zip")}"]
  deployment_file = "${join("/",slice(local.deployment_zip,length(local.deployment_zip)-5,length(local.deployment_zip)))}"
}

resource "aws_lambda_function" "service" {
  filename         = "${local.deployment_file}"
  function_name    = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  role             = "${aws_iam_role.fn.arn}"
  handler          = "app.app"
  runtime          = "python3.6"
  source_code_hash = "${base64sha256(file("${local.deployment_file}"))}"
  publish          = true

  lifecycle {
    ignore_changes = ["source_code_hash", "filename"]
  }
}

module "fn_service" {
  source           = "./module/fogg-api-gateway//module/fn"
  function_name    = "${aws_lambda_function.service.function_name}"
  function_arn     = "${aws_lambda_function.service.arn}"
  function_version = "${aws_lambda_function.service.version}"
  source_arn       = "arn:aws:execute-api:${var.env_region}:${data.aws_caller_identity.current.account_id}:${data.terraform_remote_state.env.api_gateway}/*/*/*"
  unique_prefix    = "${data.terraform_remote_state.env.api_gateway}-${data.terraform_remote_state.env.api_gateway_resource}"
}

module "resource_service" {
  source = "./module/fogg-api-gateway//module/resource"

  http_method = "POST"
  api_name    = "${var.service_name}"
  invoke_arn  = "${aws_lambda_function.service.invoke_arn}"

  rest_api_id = "${data.terraform_remote_state.env.api_gateway}"
  resource_id = "${data.terraform_remote_state.env.api_gateway_resource}"
}

resource "aws_elasticache_cluster" "service" {
  cluster_id           = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  engine               = "redis"
  engine_version       = "3.2.4"
  node_type            = "cache.t2.micro"
  port                 = 6379
  num_cache_nodes      = 1
  parameter_group_name = "${aws_elasticache_parameter_group.service.name}"
  subnet_group_name    = "${aws_elasticache_subnet_group.service.name}"
  security_group_ids   = ["${aws_security_group.cache.id}"]

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-cache"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}-cache"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_elasticache}"
}

resource "aws_elasticache_parameter_group" "service" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${uuid()}"

  family = "redis3.2"

  lifecycle {
    ignore_changes = ["name"]
  }

  count = "${var.want_elasticache}"
}

resource "aws_elasticache_subnet_group" "service" {
  name       = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  subnet_ids = ["${compact(concat(aws_subnet.service.*.id,aws_subnet.service_v6.*.id,formatlist(var.want_subnets ? "%[3]s" : (var.public_network ? "%[1]s" : "%[2]s"),data.terraform_remote_state.env.public_subnets,data.terraform_remote_state.env.private_subnets,data.terraform_remote_state.env.fake_subnets)))}"]

  count = "${var.want_elasticache}"
}

resource "aws_lb" "net" {
  name               = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  load_balancer_type = "network"
  internal           = "${var.public_lb == 0 ? true : false}"

  tags {
    Name      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    Env       = "${data.terraform_remote_state.env.env_name}"
    App       = "${data.terraform_remote_state.app.app_name}"
    Service   = "${var.service_name}"
    ManagedBy = "terraform"
    Color     = "${element(var.asg_name,count.index)}"
  }

  count = "${var.want_nlb*var.asg_count}"
}

resource "aws_lb" "app" {
  name               = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  load_balancer_type = "application"
  internal           = "${var.public_lb == 0 ? true : false}"

  tags {
    Name      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    Env       = "${data.terraform_remote_state.env.env_name}"
    App       = "${data.terraform_remote_state.app.app_name}"
    Service   = "${var.service_name}"
    ManagedBy = "terraform"
    Color     = "${element(var.asg_name,count.index)}"
  }

  idle_timeout    = 400
  security_groups = []
  subnets         = []

  access_logs {
    bucket  = ""
    prefix  = ""
    enabled = true
  }

  count = "${var.want_alb*var.asg_count}"
}

resource "aws_lb_listener" "net" {
  load_balancer_arn = "${element(aws_lb.net.*.arn,count.index)}"
  port              = 443
  protocol          = "TCP"

  default_action {
    target_group_arn = "${element(aws_lb_target_group.net.*.arn,count.index)}"
    type             = "forward"
  }

  certificate_arn = "${data.aws_acm_certificate.env.arn}"

  ssl_policy = "ELBSecurityPolicy-2015-05"

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

  count = "${var.want_alb*var.asg_count}"
}

resource "aws_lb_target_group" "net" {
  name     = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  port     = 443
  protocol = "TCP"
  vpc_id   = "${data.aws_vpc.current.id}"
  count    = "${var.want_nlb*var.asg_count}"
}

resource "aws_lb_target_group" "app" {
  name     = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${data.aws_vpc.current.id}"
  count    = "${var.want_alb*var.asg_count}"
}

resource "aws_route53_record" "net" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "A"

  alias {
    name                   = "${element(concat(aws_lb.net.*.dns_name),count.index)}"
    zone_id                = "${element(concat(aws_lb.net.*.zone_id),count.index)}"
    evaluate_target_health = false
  }

  count = "${var.asg_count*signum(var.want_nlb)}"
}

resource "aws_route53_record" "app" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "A"

  alias {
    name                   = "${element(concat(aws_lb.app.*.dns_name),count.index)}"
    zone_id                = "${element(concat(aws_lb.app.*.zone_id),count.index)}"
    evaluate_target_health = false
  }

  count = "${var.asg_count*signum(var.want_alb)}"
}
