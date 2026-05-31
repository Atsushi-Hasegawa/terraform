output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.subnet_ids
}

output "app_sg_id" {
  description = "Security group ID for application instances"
  value       = module.vpc.ecs_sg_id
}

output "alb_sg_id" {
  description = "Security group ID for the ALB"
  value       = module.vpc.alb_sg_id
}
