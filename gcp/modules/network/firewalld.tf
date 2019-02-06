resource "google_compute_firewall" "web" {
  name    = "${var.compute_firewall_name}"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = "${var.ports}"
  }

  source_tags = ["${var.env}-${var.tags}"]
}
