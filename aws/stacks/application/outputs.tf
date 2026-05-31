output "alb_dns_name" {
  description = "The DNS name of the application load balancer"
  value       = module.app-lb.lb_dns_name
}
