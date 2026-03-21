data "aws_route53_zone" "private" {
  name         = format("%s.", var.private_domain)
  private_zone = true
}

resource "aws_route53_record" "writer" {
  zone_id = data.aws_route53_zone.private.zone_id
  name    = format("%s-%s-w.%s", var.project, var.environment, var.private_domain)
  type    = "CNAME"
  ttl     = 30
  records = [aws_rds_cluster.base.endpoint]
}

resource "aws_route53_record" "reader" {
  zone_id = data.aws_route53_zone.private.zone_id
  name    = format("%s-%s-r.%s", var.project, var.environment, var.private_domain)
  type    = "CNAME"
  ttl     = 30
  records = [aws_rds_cluster.base.reader_endpoint]
}

data "dns_a_record_set" "instance_ips" {
  count = var.enable_databricks_federated ? var.instance_count : 0
  host  = aws_rds_cluster_instance.base[count.index].endpoint
}

data "dns_a_record_set" "federated_reader_ips" {
  count = var.enable_databricks_federated ? 1 : 0
  host  = aws_route53_record.reader.fqdn
}