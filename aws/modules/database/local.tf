data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  region     = data.aws_region.current.id
  account_id = data.aws_caller_identity.current.account_id

  # Default Databricks Serverless role for the current region
  databricks_serverless_role = "arn:aws:iam::565502421330:role/private-connectivity-role-${local.region}"

  # Combine user-provided ARNs with the mandatory serverless role
  all_allowed_principals = distinct(concat(var.allowed_principal_arns, [local.databricks_serverless_role]))

  # Collect all IPs from individual instance lookups to ensure all 10 nodes are utilized
  reader_ip_list = var.enable_databricks_federated ? toset(flatten(data.dns_a_record_set.instance_ips[*].addrs)) : toset([])
}
    