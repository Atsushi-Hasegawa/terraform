output "cluster_endpoint" {
  description = "The cluster writer endpoint for administrative tasks (DDL/DCL)"
  value       = aws_rds_cluster.base.endpoint
}

output "reader_endpoint" {
  description = "The cluster reader endpoint for read-only access"
  value       = aws_rds_cluster.base.reader_endpoint
}

output "database_name" {
  description = "The name of the database"
  value       = aws_rds_cluster.base.database_name
}

output "privatelink_service_name" {
  description = "The name of the PrivateLink VPC Endpoint Service"
  value       = var.enable_databricks_federated ? aws_vpc_endpoint_service.privatelink_service[0].service_name : null
}

output "rds_security_group_id" {
  description = "The ID of the security group for the RDS cluster"
  value       = var.rds_security_group_id
}
