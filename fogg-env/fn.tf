data "aws_caller_identity" "current" {}

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

data "aws_iam_policy_document" "executor" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }
}

resource "aws_iam_role" "fn" {
  name               = "${var.env_name}-executor"
  assume_role_policy = "${data.aws_iam_policy_document.fn.json}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy" "executor" {
  name        = "${aws_iam_role.fn.name}"
  description = "${aws_iam_role.fn.name}"
  policy      = "${data.aws_iam_policy_document.executor.json}"

  lifecycle {
    ignore_changes = ["policy"]
  }
}

resource "aws_iam_role_policy_attachment" "executor" {
  role       = "${aws_iam_role.fn.name}"
  policy_arn = "${aws_iam_policy.executor.arn}"
}

data "aws_iam_policy_document" "apigateway" {
  statement {
    actions = [
      "execute-api:Invoke",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "*",
    ]
  }
}

resource "aws_api_gateway_rest_api" "env" {
  name   = "${var.env_name}"
  policy = "${data.aws_iam_policy_document.apigateway.json}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_domain_name" "env" {
  domain_name              = "${aws_route53_zone.private.name}"
  regional_certificate_arn = "${local.env_cert}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_domain_name" "env_rc" {
  domain_name              = "rc-${aws_route53_zone.private.name}"
  regional_certificate_arn = "${local.env_cert}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_route53_record" "env_api_gateway" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${aws_api_gateway_domain_name.env.domain_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_api_gateway_domain_name.env.regional_zone_id}"
    name                   = "${aws_api_gateway_domain_name.env.regional_domain_name}"
    evaluate_target_health = "true"
  }
}

resource "aws_route53_record" "env_api_gateway_rc" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${aws_api_gateway_domain_name.env_rc.domain_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_api_gateway_domain_name.env_rc.regional_zone_id}"
    name                   = "${aws_api_gateway_domain_name.env_rc.regional_domain_name}"
    evaluate_target_health = "true"
  }
}

resource "aws_route53_record" "env_api_gateway_private" {
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "${aws_api_gateway_domain_name.env.domain_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_api_gateway_domain_name.env.regional_zone_id}"
    name                   = "${aws_api_gateway_domain_name.env.regional_domain_name}"
    evaluate_target_health = "true"
  }
}

locals {
  deployment_file = "fn/dist/deployment.zip"
}

resource "aws_lambda_function" "env" {
  filename         = "${local.deployment_file}"
  function_name    = "${var.env_name}"
  role             = "${aws_iam_role.fn.arn}"
  handler          = "app.handler"
  runtime          = "nodejs8.10"
  source_code_hash = "${base64sha256(file("${local.deployment_file}"))}"
  publish          = true

  lifecycle {
    ignore_changes = ["source_code_hash", "filename", "last_modified", "qualified_arn", "version"]
  }
}

module "fn_hello" {
  source           = ".module/fogg-tf/fogg-api/fn"
  function_name    = "${aws_lambda_function.env.function_name}"
  function_arn     = "${aws_lambda_function.env.arn}"
  function_version = "${aws_lambda_function.env.version}"
  source_arn_live  = "${module.stage_live.execution_arn}/*"
  source_arn_rc    = "${module.stage_rc.execution_arn}/*"
  unique_prefix    = "${aws_api_gateway_rest_api.env.id}-${aws_api_gateway_rest_api.env.root_resource_id}"
}

module "resource_helo" {
  source = ".module/fogg-tf/fogg-api/root"

  invoke_arn = "${aws_lambda_function.env.invoke_arn}"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  resource_id = "${aws_api_gateway_rest_api.env.root_resource_id}"
}

module "resource_hello" {
  source = ".module/fogg-tf/fogg-api/resource"

  api_name   = "{proxy+}"
  invoke_arn = "${aws_lambda_function.env.invoke_arn}"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  resource_id = "${aws_api_gateway_rest_api.env.root_resource_id}"
}

resource "aws_api_gateway_deployment" "env" {
  rest_api_id = "${aws_api_gateway_rest_api.env.id}"

  description = "${module.resource_helo.resource}/${module.resource_hello.resource}"
  stage_name  = "rc"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = ["stage_name"]
  }

  variables = {
    helo_resource     = "${module.resource_helo.resource}"
    helo_method       = "${module.resource_helo.method}"
    helo_integration  = "${module.resource_helo.integration}"
    hello_resource    = "${module.resource_hello.resource}"
    hello_method      = "${module.resource_hello.method}"
    hello_integration = "${module.resource_hello.integration}"
  }
}

module "stage_rc" {
  source = ".module/fogg-tf/fogg-api/stage"

  stage_name    = "rc"
  rest_api_id   = "${aws_api_gateway_rest_api.env.id}"
  domain_name   = "${aws_api_gateway_domain_name.env_rc.domain_name}"
  deployment_id = "${aws_api_gateway_deployment.env.id}"
}

module "stage_live" {
  source = ".module/fogg-tf/fogg-api/stage"

  stage_name    = "live"
  rest_api_id   = "${aws_api_gateway_rest_api.env.id}"
  domain_name   = "${aws_api_gateway_domain_name.env.domain_name}"
  deployment_id = "${aws_api_gateway_deployment.env.id}"
}
