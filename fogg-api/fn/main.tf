variable "function_name" {}
variable "function_arn" {}

variable "function_version" {
  default = ""
}

variable "unique_prefix" {}
variable "source_arn_live" {}
variable "source_arn_rc" {}

variable "fn_rc" {
  default = "$LATEST"
}

variable "fn_live" {
  default = "$LATEST"
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = "${var.function_arn}"
  function_version = "${coalesce(var.function_version,var.fn_live)}"

  lifecycle {
    ignore_changes = ["function_version"]
  }
}

resource "aws_lambda_alias" "rc" {
  name             = "rc"
  function_name    = "${var.function_arn}"
  function_version = "${var.fn_rc}"

  lifecycle {
    ignore_changes = ["function_version"]
  }
}

resource "aws_lambda_permission" "live" {
  depends_on    = ["aws_lambda_alias.live"]
  statement_id  = "${var.unique_prefix}-${var.function_name}-live"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = "${var.function_name}"
  source_arn    = "${var.source_arn_live}/"
  qualifier     = "live"
}

resource "aws_lambda_permission" "live_proxy" {
  depends_on    = ["aws_lambda_alias.live"]
  statement_id  = "${var.unique_prefix}-${var.function_name}-live-proxy"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = "${var.function_name}"
  source_arn    = "${var.source_arn_live}/{proxy+}"
  qualifier     = "live"
}

resource "aws_lambda_permission" "rc" {
  depends_on    = ["aws_lambda_alias.rc"]
  statement_id  = "${var.unique_prefix}-${var.function_name}-rc"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = "${var.function_name}"
  source_arn    = "${var.source_arn_rc}/"
  qualifier     = "rc"
}

resource "aws_lambda_permission" "rc_proxy" {
  depends_on    = ["aws_lambda_alias.rc"]
  statement_id  = "${var.unique_prefix}-${var.function_name}-rc-proxy"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = "${var.function_name}"
  source_arn    = "${var.source_arn_rc}/{proxy+}"
  qualifier     = "rc"
}
