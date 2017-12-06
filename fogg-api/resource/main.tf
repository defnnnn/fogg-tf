variable "api_name" {}
variable "rest_api_id" {}
variable "resource_id" {}
variable "invoke_arn" {}
variable "want_vpc_link" {
  default = 0
}

variable "http_method" {
  default = "POST"
}

# /$name
resource "aws_api_gateway_resource" "fn" {
  rest_api_id = "${var.rest_api_id}"
  parent_id   = "${var.resource_id}"
  path_part   = "${var.api_name}"
}

resource "aws_api_gateway_method" "fn" {
  rest_api_id   = "${var.rest_api_id}"
  resource_id   = "${aws_api_gateway_resource.fn.id}"
  http_method   = "${var.http_method}"
  authorization = "NONE"
}

# /$name/{ps+}
resource "aws_api_gateway_resource" "fn_catch_all" {
  rest_api_id = "${var.rest_api_id}"
  parent_id   = "${aws_api_gateway_resource.fn.id}"
  path_part   = "{ps+}"
}

resource "aws_api_gateway_method" "fn_catch_all" {
  rest_api_id   = "${var.rest_api_id}"
  resource_id   = "${aws_api_gateway_resource.fn_catch_all.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

# lambda backend
resource "aws_api_gateway_integration" "fn" {
  rest_api_id             = "${var.rest_api_id}"
  resource_id             = "${aws_api_gateway_resource.fn.id}"
  uri                     = "${replace(var.invoke_arn,"/invocations",":$${stageVariables.alias}/invocations")}"
  http_method             = "${aws_api_gateway_method.fn.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  content_handling        = "CONVERT_TO_TEXT"
  count = "${(var.want_vpc_link - 1)* -1}"
}

resource "aws_api_gateway_integration" "fn_catch_all" {
  rest_api_id             = "${var.rest_api_id}"
  resource_id             = "${aws_api_gateway_resource.fn_catch_all.id}"
  uri                     = "${replace(var.invoke_arn,"/invocations",":$${stageVariables.alias}/invocations")}"
  http_method             = "${aws_api_gateway_method.fn_catch_all.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  content_handling        = "CONVERT_TO_TEXT"
  count = "${(var.want_vpc_link - 1)* -1}"
}

output "resource" {
  value = "${aws_api_gateway_resource.fn.id}"
}

