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

resource "aws_iam_role" "fn" {
  name               = "${var.env_name}-fn"
  assume_role_policy = "${data.aws_iam_policy_document.fn.json}"
}

resource "aws_api_gateway_rest_api" "env" {
  name = "${var.env_name}"
}

resource "null_resource" "aws_api_gateway_rest_api_env" {
  depends_on = ["aws_api_gateway_rest_api.env"]

  provisioner "local-exec" {
    command = "aws apigateway update-rest-api --region ${var.region} --rest-api-id ${aws_api_gateway_rest_api.env.id} --patch-operations op=replace,path=/endpointConfiguration/types/EDGE,value=REGIONAL"
  }
}

resource "aws_api_gateway_domain_name" "env" {
  domain_name     = "${aws_route53_zone.private.name}"
  certificate_arn = "${data.terraform_remote_state.org.wildcard_cert}"
}

resource "null_resource" "aws_api_gateway_domain_name_env" {
  depends_on = ["aws_api_gateway_domain_name.env"]

  provisioner "local-exec" {
    command = "aws apigateway update-domain-name --region ${var.region} --domain-name ${aws_api_gateway_domain_name.env.domain_name} --patch-operations op='add',path='/endpointConfiguration/types',value='REGIONAL' op='add',path='/regionalCertificateArn',value='${data.terraform_remote_state.org.wildcard_cert}'; aws apigateway update-domain-name --region ${var.region} --domain-name ${aws_api_gateway_domain_name.env.domain_name} --patch-operations op='remove',path='/endpointConfiguration/types',value='EDGE'"
  }
}

resource "aws_route53_record" "env_api_gateway" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${aws_route53_zone.private.name}"
  type    = "A"

  alias {
    name                   = "${aws_api_gateway_domain_name.env.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.env.cloudfront_zone_id}"
    evaluate_target_health = "true"
  }

  count = 0
}

resource "aws_route53_record" "env_api_gateway_private" {
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "${aws_route53_zone.private.name}"
  type    = "A"

  alias {
    name                   = "${aws_api_gateway_domain_name.env.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.env.cloudfront_zone_id}"
    evaluate_target_health = "true"
  }

  count = 0
}

locals {
  deployment_zip  = ["${split("/","${path.module}/fn/dist/deployment.zip")}"]
  deployment_file = "${join("/",slice(local.deployment_zip,length(local.deployment_zip)-6,length(local.deployment_zip)))}"
}

resource "aws_lambda_function" "env" {
  filename         = "${local.deployment_file}"
  function_name    = "${var.env_name}"
  role             = "${aws_iam_role.fn.arn}"
  handler          = "app.app"
  runtime          = "python3.6"
  source_code_hash = "${base64sha256(file("${local.deployment_file}"))}"
  publish          = true

  lifecycle {
    ignore_changes = ["source_code_hash", "filename"]
  }
}

module "fn_hello" {
  source           = "./module/fogg-tf/fogg-api/fn"
  function_name    = "${aws_lambda_function.env.function_name}"
  function_arn     = "${aws_lambda_function.env.arn}"
  function_version = "${aws_lambda_function.env.version}"
  source_arn       = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.env.id}/*/*/*"
  unique_prefix    = "${aws_api_gateway_rest_api.env.id}-${aws_api_gateway_rest_api.env.root_resource_id}"
}

module "resource_hello" {
  source = "./module/fogg-tf/fogg-api/resource"

  api_name   = "hello"
  invoke_arn = "${aws_lambda_function.env.invoke_arn}"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  resource_id = "${aws_api_gateway_rest_api.env.root_resource_id}"
}

module "stage_rc" {
  source = "./module/fogg-tf/fogg-api/stage"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  domain_name = "${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}"
  stage_name  = "rc"

  anchor = "${module.resource_hello.resource}"
}

module "stage_live" {
  source = "./module/fogg-tf/fogg-api/stage"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  domain_name = "${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}"
  stage_name  = "live"

  anchor = "${module.stage_rc.deployment}"
}
