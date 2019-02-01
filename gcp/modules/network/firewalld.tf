variable "zone" {}
variable "compute_firewall_name" {}
variable "ports" {}
variable "tags" {}

resource "google_compute_firewall" "web" {
  name = "${var.compute_firewall_name}"
  network = "${google_compute_network.web-network.name}"

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports = ["${split(",", var.ports)}"]
  }

  source_tags = ["${var.tags}"]
}
