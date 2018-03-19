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
  certificate_arn = "${data.aws_acm_certificate.us_east_1.arn}"
}

resource "aws_api_gateway_domain_name" "env_rc" {
  domain_name     = "rc-${aws_route53_zone.private.name}"
  certificate_arn = "${data.aws_acm_certificate.us_east_1.arn}"
}

resource "null_resource" "aws_api_gateway_domain_name_env" {
  depends_on = ["aws_api_gateway_domain_name.env"]

  provisioner "local-exec" {
    command = "aws apigateway update-domain-name --region ${var.region} --domain-name ${aws_api_gateway_domain_name.env.domain_name} --patch-operations op='add',path='/endpointConfiguration/types',value='REGIONAL' op='add',path='/regionalCertificateArn',value='${local.env_cert}'"
  }

  provisioner "local-exec" {
    command = " aws apigateway update-domain-name --region ${var.region} --domain-name ${aws_api_gateway_domain_name.env.domain_name} --patch-operations op='remove',path='/endpointConfiguration/types',value='EDGE'"
  }
}

resource "null_resource" "aws_api_gateway_domain_name_env_rc" {
  depends_on = ["aws_api_gateway_domain_name.env_rc"]

  provisioner "local-exec" {
    command = "aws apigateway update-domain-name --region ${var.region} --domain-name ${aws_api_gateway_domain_name.env_rc.domain_name} --patch-operations op='add',path='/endpointConfiguration/types',value='REGIONAL' op='add',path='/regionalCertificateArn',value='${local.env_cert}'"
  }

  provisioner "local-exec" {
    command = " aws apigateway update-domain-name --region ${var.region} --domain-name ${aws_api_gateway_domain_name.env_rc.domain_name} --patch-operations op='remove',path='/endpointConfiguration/types',value='EDGE'"
  }
}

locals {
  apig_domain_zone_id    = "${aws_api_gateway_domain_name.env.cloudfront_zone_id}"
  apig_domain_zone_id_rc = "${aws_api_gateway_domain_name.env_rc.cloudfront_zone_id}"
  apig_domain_name       = "${aws_api_gateway_domain_name.env.cloudfront_domain_name}"
  apig_domain_name_rc    = "${aws_api_gateway_domain_name.env_rc.cloudfront_domain_name}"
}

resource "aws_route53_record" "env_api_gateway" {
  depends_on = ["null_resource.aws_api_gateway_domain_name_env"]

  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${aws_route53_zone.private.name}"
  type    = "A"

  alias {
    zone_id                = "${local.apig_domain_zone_id}"
    name                   = "${local.apig_domain_name}"
    evaluate_target_health = "true"
  }
}

resource "aws_route53_record" "env_api_gateway_rc" {
  depends_on = ["null_resource.aws_api_gateway_domain_name_env_rc"]

  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${aws_route53_zone.private.name}"
  type    = "A"

  alias {
    zone_id                = "${local.apig_domain_zone_id_rc}"
    name                   = "${local.apig_domain_name_rc}"
    evaluate_target_health = "true"
  }
}

resource "aws_route53_record" "env_api_gateway_private" {
  depends_on = ["null_resource.aws_api_gateway_domain_name_env"]

  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "${aws_route53_zone.private.name}"
  type    = "A"

  alias {
    zone_id                = "${local.apig_domain_zone_id}"
    name                   = "${local.apig_domain_name}"
    evaluate_target_health = "true"
  }
}

resource "aws_route53_record" "env_api_gateway_private_rc" {
  depends_on = ["null_resource.aws_api_gateway_domain_name_env_rc"]

  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "rc-${aws_route53_zone.private.name}"
  type    = "A"

  alias {
    zone_id                = "${local.apig_domain_zone_id_rc}"
    name                   = "${local.apig_domain_name_rc}"
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
  handler          = "main"
  runtime          = "go1.x"
  source_code_hash = "${base64sha256(file("${local.deployment_file}"))}"
  publish          = true
}

module "fn_hello" {
  source           = "./module/fogg-tf/fogg-api/fn"
  function_name    = "${aws_lambda_function.env.function_name}"
  function_arn     = "${aws_lambda_function.env.arn}"
  function_version = "${aws_lambda_function.env.version}"
  source_arn       = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.env.id}/*/*/*"
  unique_prefix    = "${aws_api_gateway_rest_api.env.id}-${aws_api_gateway_rest_api.env.root_resource_id}"
}

module "resource_helo" {
  source = "./module/fogg-tf/fogg-api/root"

  invoke_arn = "${aws_lambda_function.env.invoke_arn}"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  resource_id = "${aws_api_gateway_rest_api.env.root_resource_id}"
}

module "resource_hello" {
  source = "./module/fogg-tf/fogg-api/resource"

  api_name   = "{proxy+}"
  invoke_arn = "${aws_lambda_function.env.invoke_arn}"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  resource_id = "${aws_api_gateway_rest_api.env.root_resource_id}"
}

module "stage_rc" {
  source = "./module/fogg-tf/fogg-api/stage"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  domain_name = "rc-${aws_route53_zone.private.name}"
  stage_name  = "rc"
}

module "stage_live" {
  source = "./module/fogg-tf/fogg-api/stage"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  domain_name = "${aws_route53_zone.private.name}"
  stage_name  = "live"
}
