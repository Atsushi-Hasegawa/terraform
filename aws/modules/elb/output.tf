output "target_group_arn" {
  value = aws_lb_target_group.target-group.arn
}

output "lb_dns_name" {
  value = aws_lb.app-lb.dns_name
}

output "vpc_id" {
  value = aws_lb_target_group.target-group.vpc_id
}

output "waf_acl_arn" {
  value = aws_wafv2_web_acl.alb_waf.arn
}
