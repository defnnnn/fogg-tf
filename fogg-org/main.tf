provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "eu_central_1"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "ap_southeast_2"
  region = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {
  current = true
}

data "aws_acm_certificate" "website" {
  provider = "aws.us_east_1"
  domain   = "*.${var.domain_name}"
  statuses = ["ISSUED", "PENDING_VALIDATION"]
}

resource "null_resource" "vars" {
  triggers {
    region_account_id = "${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_iam_group" "administrators" {
  name = "administrators"
}

resource "aws_iam_group_policy_attachment" "administrators_iam_full_access" {
  group      = "${aws_iam_group.administrators.name}"
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_group_policy_attachment" "administrators_administrator_access" {
  group      = "${aws_iam_group.administrators.name}"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_group" "operators" {
  name = "operators"
}

resource "aws_iam_group_policy" "operators" {
  name  = "operators"
  group = "${aws_iam_group.operators.id}"

  policy = "${data.aws_iam_policy_document.operators.json}"
}

data "aws_iam_policy_document" "operators" {
  statement {
    actions = [
      "kms:Encrypt",
    ]

    resources = [
      "arn:aws:kms:${null_resource.vars.triggers.region_account_id}:key/*",
    ]

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:to"
      values   = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:user_type"
      values   = ["user"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:from"
      values   = ["$${aws:username}"]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_s3_bucket" "meta" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-meta"
  acl    = "log-delivery-write"

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_s3_bucket" "s3" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
  acl    = "log-delivery-write"

  depends_on = ["aws_s3_bucket.meta"]

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-meta"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_s3_bucket" "tf_remote_state" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-tf-remote-state"
  acl    = "private"

  depends_on = ["aws_s3_bucket.s3"]

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_s3_bucket" "cache" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cache"
  acl    = "private"

  depends_on = ["aws_s3_bucket.s3"]

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_s3_bucket" "config" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-config"
  acl    = "private"
  policy = "${data.aws_iam_policy_document.config_s3.json}"

  depends_on = ["aws_s3_bucket.s3"]

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_iam_role_policy" "config_s3" {
  name = "config-s3"
  role = "${aws_iam_role.config.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
				"s3:GetBucketAcl"
			],
      "Resource": [
        "${aws_s3_bucket.config.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
				"s3:PutObject"
			],
      "Resource": [
        "${aws_s3_bucket.config.arn}/AwsLogs/*"
      ],
      "Condition": { 
        "StringLike": { 
          "s3:x-amz-acl": "bucket-owner-full-control" 
        }
      }
    }
  ]
}
POLICY
}

data "aws_iam_policy_document" "config_sns" {
  statement {
    actions = [
      "SNS:Publish",
    ]

    resources = [
      "arn:aws:sns:${null_resource.vars.triggers.region_account_id}:config",
    ]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic" "config" {
  name   = "config"
  policy = "${data.aws_iam_policy_document.config_sns.json}"
}

resource "aws_sqs_queue" "config" {
  name   = "config"
  policy = "${data.aws_iam_policy_document.config_sns_sqs.json}"
}

data "aws_iam_policy_document" "config_sns_sqs" {
  statement {
    actions = [
      "sqs:SendMessage",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:sqs:${null_resource.vars.triggers.region_account_id}:config",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        "${aws_sns_topic.config.arn}",
      ]
    }
  }
}

resource "aws_sns_topic_subscription" "config" {
  topic_arn = "${aws_sns_topic.config.arn}"
  endpoint  = "${aws_sqs_queue.config.arn}"
  protocol  = "sqs"
}

resource "aws_iam_role_policy" "config_sns" {
  name = "config-sns"
  role = "${aws_iam_role.config.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
			],
      "Resource": [
        "${aws_sns_topic.config.arn}"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role" "config" {
  name = "config"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = "${aws_iam_role.config.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_config_delivery_channel" "config" {
  name           = "config"
  s3_bucket_name = "${aws_s3_bucket.config.bucket}"
  sns_topic_arn  = "${aws_sns_topic.config.arn}"
}

resource "aws_config_configuration_recorder" "config" {
  name     = "config"
  role_arn = "${aws_iam_role.config.arn}"

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "config" {
  name       = "${aws_config_configuration_recorder.config.name}"
  is_enabled = true
  depends_on = ["aws_config_delivery_channel.config"]
}

data "aws_billing_service_account" "global" {}

data "aws_iam_policy_document" "billing" {
  statement {
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-billing",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_billing_service_account.global.id}:root"]
    }
  }

  statement {
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-billing/AWSLogs/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_billing_service_account.global.id}:root"]
    }
  }
}

data "aws_iam_policy_document" "config_s3" {
  statement {
    actions = [
      "s3:GetBucketAcl",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-config",
    ]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-config/AWSLogs/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket" "billing" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-billing"
  acl    = "private"
  policy = "${data.aws_iam_policy_document.billing.json}"

  depends_on = ["aws_s3_bucket.s3"]

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_cloudtrail" "global" {
  name                          = "global-cloudtrail"
  s3_bucket_name                = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
}

data "aws_iam_policy_document" "cloudtrail" {
  statement {
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cloudtrail",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cloudtrail/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cloudtrail"
  policy = "${data.aws_iam_policy_document.cloudtrail.json}"
}

resource "aws_route53_zone" "public" {
  name = "${var.domain_name}"

  tags {
    "Name"      = "${var.domain_name}"
    "Env"       = "global"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route53_record" "website" {
  zone_id = "${aws_route53_zone.public.zone_id}"
  name    = "cdn.${var.domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.website.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform_state_lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_ses_receipt_rule_set" "org" {
  provider      = "aws.us_east_1"
  rule_set_name = "${var.domain_name}"
}

resource "aws_ses_active_receipt_rule_set" "org" {
  provider      = "aws.us_east_1"
  rule_set_name = "${var.domain_name}"
  depends_on    = ["aws_ses_receipt_rule_set.org"]
}

resource "aws_iam_account_alias" "org" {
  account_alias = "${var.account_name}"
}

resource "aws_s3_bucket" "website" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cdn"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "404.html"
    routing_rules  = ""
  }

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "1",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_cloudfront_origin_access_identity.website.iam_arn}"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cdn/*"
        },
        {
          "Sid": "2",
          "Principal": {
            "AWS": "*"
          },
          "Effect": "Allow",
          "Action": [
            "s3:GetObject"
          ],
          "Resource": "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cdn/*",
          "Condition": {
            "StringEquals": {
              "aws:UserAgent": "${var.cdn_secret}"
            }
          }
        }
      ]
}
EOF

  tags {
    "Env"       = "global"
    "ManagedBy" = "terraform"
  }
}

resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cdn"
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cdn.s3-website-${data.aws_region.current.name}.amazonaws.com"
    origin_id   = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cdn"

    #s3_origin_config {
    #  origin_access_identity = "${aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path}"
    #}

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1"]
    }
    custom_header {
      name  = "User-Agent"
      value = "${var.cdn_secret}"
    }
  }

  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  aliases = ["cdn.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true
    target_origin_id = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cdn"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "${data.aws_acm_certificate.website.arn}"
    minimum_protocol_version = "TLSv1.2_2018"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_codecommit_repository" "org" {
  repository_name = "${var.account_name}"
  description     = "Repo for ${var.account_name} org"
}

resource "aws_kms_key" "org_us_east_1" {
  provider            = "aws.us_east_1"
  description         = "Organization ${var.account_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
    "Name"      = "${var.account_name}"
  }
}

resource "aws_kms_alias" "ssm_ps_us_east_1" {
  provider      = "aws.us_east_1"
  name          = "alias/parameter_store_key"
  target_key_id = "${aws_kms_key.org_us_east_1.key_id}"
}

resource "aws_kms_alias" "credstash_us_east_1" {
  provider      = "aws.us_east_1"
  name          = "alias/credstash"
  target_key_id = "${aws_kms_key.org_us_east_1.key_id}"
}

resource "aws_kms_key" "org_us_east_2" {
  provider            = "aws.us_east_2"
  description         = "Organization ${var.account_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
    "Name"      = "${var.account_name}"
  }
}

resource "aws_kms_alias" "ssm_ps_us_east_2" {
  provider      = "aws.us_east_2"
  name          = "alias/parameter_store_key"
  target_key_id = "${aws_kms_key.org_us_east_2.key_id}"
}

resource "aws_kms_alias" "credstash_us_east_2" {
  provider      = "aws.us_east_2"
  name          = "alias/credstash"
  target_key_id = "${aws_kms_key.org_us_east_2.key_id}"
}

resource "aws_kms_key" "org_us_west_2" {
  provider            = "aws.us_west_2"
  description         = "Organization ${var.account_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
    "Name"      = "${var.account_name}"
  }
}

resource "aws_kms_alias" "ssm_ps_us_west_2" {
  provider      = "aws.us_west_2"
  name          = "alias/parameter_store_key"
  target_key_id = "${aws_kms_key.org_us_west_2.key_id}"
}

resource "aws_kms_alias" "credstash_us_west_2" {
  provider      = "aws.us_west_2"
  name          = "alias/credstash"
  target_key_id = "${aws_kms_key.org_us_west_2.key_id}"
}

resource "aws_kms_key" "org_eu_west_1" {
  provider            = "aws.eu_west_1"
  description         = "Organization ${var.account_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
    "Name"      = "${var.account_name}"
  }
}

resource "aws_kms_alias" "ssm_ps_eu_west_1" {
  provider      = "aws.eu_west_1"
  name          = "alias/parameter_store_key"
  target_key_id = "${aws_kms_key.org_eu_west_1.key_id}"
}

resource "aws_kms_alias" "credstash_eu_west_1" {
  provider      = "aws.eu_west_1"
  name          = "alias/credstash"
  target_key_id = "${aws_kms_key.org_eu_west_1.key_id}"
}

resource "aws_kms_key" "org_eu_central_1" {
  provider            = "aws.eu_central_1"
  description         = "Organization ${var.account_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
    "Name"      = "${var.account_name}"
  }
}

resource "aws_kms_alias" "ssm_ps_eu_central_1" {
  provider      = "aws.eu_central_1"
  name          = "alias/parameter_store_key"
  target_key_id = "${aws_kms_key.org_eu_central_1.key_id}"
}

resource "aws_kms_alias" "credstash_eu_central_1" {
  provider      = "aws.eu_central_1"
  name          = "alias/credstash"
  target_key_id = "${aws_kms_key.org_eu_central_1.key_id}"
}

resource "aws_kms_key" "org_ap_southeast_2" {
  provider            = "aws.ap_southeast_2"
  description         = "Organization ${var.account_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
    "Name"      = "${var.account_name}"
  }
}

resource "aws_kms_alias" "ssm_ps_ap_southeast_2" {
  provider      = "aws.ap_southeast_2"
  name          = "alias/parameter_store_key"
  target_key_id = "${aws_kms_key.org_ap_southeast_2.key_id}"
}

resource "aws_kms_alias" "credstash_ap_southeast_2" {
  provider      = "aws.ap_southeast_2"
  name          = "alias/credstash"
  target_key_id = "${aws_kms_key.org_ap_southeast_2.key_id}"
}

resource "aws_iam_role" "macie_service" {
  name  = "macie-setup"
  count = "${var.want_macie}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "macie.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "macie_service" {
  role       = "${aws_iam_role.macie_service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonMacieServiceRole"
  count      = "${var.want_macie}"
}

resource "aws_iam_role" "macie_setup" {
  name  = "macie-service"
  count = "${var.want_macie}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "macie.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "macie_setup" {
  role       = "${aws_iam_role.macie_setup.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonMacieSetupRole"
  count      = "${var.want_macie}"
}

resource "aws_iam_role_policy_attachment" "macie_setup_cloudtrail" {
  role       = "${aws_iam_role.macie_setup.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudTrailReadOnlyAccess"
  count      = "${var.want_macie}"
}

resource "aws_api_gateway_account" "org_us_east_1" {
  provider            = "aws.us_east_1"
  cloudwatch_role_arn = "${aws_iam_role.api_gateway.arn}"
}

resource "aws_api_gateway_account" "org_us_east_2" {
  provider            = "aws.us_east_2"
  cloudwatch_role_arn = "${aws_iam_role.api_gateway.arn}"
}

resource "aws_api_gateway_account" "org_us_west_2" {
  provider            = "aws.us_west_2"
  cloudwatch_role_arn = "${aws_iam_role.api_gateway.arn}"
}

resource "aws_api_gateway_account" "org_eu_west_1" {
  provider            = "aws.eu_west_1"
  cloudwatch_role_arn = "${aws_iam_role.api_gateway.arn}"
}

resource "aws_api_gateway_account" "org_eu_central_1" {
  provider            = "aws.eu_central_1"
  cloudwatch_role_arn = "${aws_iam_role.api_gateway.arn}"
}

resource "aws_api_gateway_account" "org_ap_southeast_2" {
  provider            = "aws.ap_southeast_2"
  cloudwatch_role_arn = "${aws_iam_role.api_gateway.arn}"
}

resource "aws_iam_role" "api_gateway" {
  name = "api_gateway_cloudwatch"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
        },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "api_gateway" {
  role       = "${aws_iam_role.api_gateway.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
