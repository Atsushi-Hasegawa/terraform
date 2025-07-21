output "instance_ids" {
  value = aws_instance.app.*.id
}

output "instance" {
  value = aws_instance.app
}
output "elastic_ip" {
  value = aws_eip.app
}