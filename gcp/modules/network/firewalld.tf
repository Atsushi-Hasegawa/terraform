resource "google_compute_firewall" "icmp" {
  name    = "allow-icmp"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "web" {
  count   = "${length(var.firewall)}"
  name    = "${lookup(var.firewall[count.index], "name")}"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "tcp"
    ports    = ["${lookup(var.firewall[count.index], "port")}"]
  }

  source_ranges = ["${lookup(var.firewall[count.index], "ip")}"]
  source_tags   = ["${var.env}-${lookup(var.firewall[count.index],"tag")}"]
}
