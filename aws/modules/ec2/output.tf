output "instance_ids" {
  value = "${aws_instance.app.*.id}"
}

output "instances_count" {
  value = "${aws_instance.app.count}"
}
