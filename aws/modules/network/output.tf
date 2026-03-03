output "vpc_id" {
  value = aws_vpc.vpc-main.id
}

output "subnet_ids" {
  value = aws_subnet.public_subnet.*.id
}
