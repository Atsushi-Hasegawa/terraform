output "instance_ids" {
  value = "${aws_instance.app.*.id}"
}

output "instance_count" {
  value = "${aws_instance.app.count}"
}
