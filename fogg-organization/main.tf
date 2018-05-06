provider "aws" {}

resource "aws_organizations_organization" "organization" {
  feature_set = "ALL"
}
