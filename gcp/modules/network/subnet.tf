resource "google_compute_network" "network" {
  name                    = "${lookup(var.network, "vpc_name")}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "${lookup(var.network, "subnetwork_name")}"
  ip_cidr_range = "${lookup(var.network, "subnetwork_cidr_range")}"
  network       = "${google_compute_network.network.name}"
  region        = "${var.region}"

  secondary_ip_range {
    range_name    = "${lookup(var.network, "second_range_name")}"
    ip_cidr_range = "${lookup(var.network, "ip_cidr_range")}"
  }
}

output "network" {
  value = "${
    map(
      "network", "${google_compute_network.network.self_link}",
      "subnetwork", "${google_compute_subnetwork.subnetwork.self_link}"
    )
  }"
}
