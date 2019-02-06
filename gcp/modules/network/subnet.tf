resource "google_compute_network" "network" {
  name                    = "${var.vpc_network_name}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "${var.subnetwork_name}"
  ip_cidr_range = "${var.subnetwork_cidr_range}"
  network       = "${google_compute_network.network.self_link}"
  region        = "${var.region}"
}

output "network" {
  value = "${
    map(
      "network", "${google_compute_network.network.self_link}",
      "subnetwork", "${google_compute_subnetwork.subnetwork.self_link}"
    )
  }"
}
