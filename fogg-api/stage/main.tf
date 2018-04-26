variable "rest_api_id" {}
variable "stage_name" {}
variable "domain_name" {}

resource "aws_api_gateway_stage" "stage" {
  stage_name    = "${var.stage_name}"
  rest_api_id   = "${var.rest_api_id}"
  deployment_id = "${aws_api_gateway_deployment.stage.id}"

  variables {
    alias = "${var.stage_name}"
  }
}

resource "aws_api_gateway_deployment" "stage" {
  rest_api_id = "${var.rest_api_id}"
  stage_name  = "${var.stage_name}"
  description = "${var.stage_name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method_settings" "stage" {
  depends_on  = ["aws_api_gateway_stage.stage"]
  rest_api_id = "${var.rest_api_id}"
  stage_name  = "${var.stage_name}"
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = true
  }
}

resource "aws_api_gateway_base_path_mapping" "stage" {
  depends_on  = ["aws_api_gateway_method_settings.stage"]
  api_id      = "${var.rest_api_id}"
  stage_name  = "${var.stage_name}"
  domain_name = "${var.domain_name}"
}

output "deployment" {
  value = "${aws_api_gateway_deployment.stage.id}"
}

output "invoke_url" {
  value = "${aws_api_gateway_stage.stage.invoke_url}"
}

output "execution_arn" {
  value = "${aws_api_gateway_stage.stage.execution_arn}"
}
