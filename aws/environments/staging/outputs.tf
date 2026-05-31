# Athena Outputs
output "athena_workgroup_name" {
  value = module.athena.athena_workgroup_name
}

output "athena_data_bucket_name" {
  value = module.athena.data_bucket_name
}

output "athena_glue_database_name" {
  value = module.athena.glue_database_name
}

output "athena_glue_table_name" {
  value = module.athena.glue_table_name
}

output "athena_firehose_delivery_stream_arn" {
  value = module.athena.firehose_delivery_stream_arn
}

# Application Outputs
output "alb_dns_name" {
  description = "The DNS name of the application load balancer"
  value       = module.app-lb.dns_name
}

output "ecs_cluster_name" {
  value = module.ecs-app.cluster_name
}
