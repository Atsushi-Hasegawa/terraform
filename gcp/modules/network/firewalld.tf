variable "zone" {}
variable "compute_firewall_name" {}
variable "ports" {}
variable "tags" {}

resource "google_compute_firewall" "compute-firewall" {
  name = "${var.compute_firewall_name}"
  network = "${google_compute_network.vpc-network.name}"

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports = ["${split(",", var.ports)}"]
  }

  source_tags = ["${var.tags}"]
}
