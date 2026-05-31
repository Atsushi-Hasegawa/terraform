output "instance_ids" {
  value = aws_instance.app.*.id
}

output "instance_count" {
  value = length(aws_instance.app.*.id)
}

output "instance" {
  value = aws_instance.app
}

output "instance_type" {
  value = var.instance_type
}

output "vpc_security_group_ids" {
  value = aws_instance.app[0].vpc_security_group_ids
}

output "instance_tags" {
  value = [for inst in aws_instance.app : inst.tags]
}
