resource "google_redis_instance" "redis" {
  name           = "${lookup(var.redis, "name")}"
  tier           = "${lookup(var.redis, "tier")}"
  memory_size_gb = "${lookup(var.redis, "memory_size_gb")}"

  location_id             = "${lookup(var.redis, "location_id")}"
  alternative_location_id = "${lookup(var.redis, "alternative_location_id")}"

  authorized_network = "${lookup(var.network, "network")}"

  redis_version     = "${lookup(var.redis, "version")}"
  reserved_ip_range = "${lookup(var.redis, "reserved_ip_range")}"
}
