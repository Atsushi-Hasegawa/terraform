output "target_group_arn" {
  value = aws_lb_target_group.target-group.arn
}

output "lb_dns_name" {
  value = aws_lb.app-lb.dns_name
}
