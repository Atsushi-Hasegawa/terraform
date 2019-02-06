resource "google_compute_instance" "compute-instance" {
  count        = "${lookup(var.engine, "count")}"
  name         = "${lookup(var.engine, "instance_name")}"
  machine_type = "${lookup(var.engine, "machine_type")}"
  zone         = "${var.zone}"

  boot_disk {
    initialize_params {
      size  = "${lookup(var.engine, "size_gb")}"
      type  = "${lookup(var.engine, "type")}"
      image = "${lookup(var.engine, "image")}"
    }
  }

  network_interface = {
    subnetwork    = "${lookup(var.network, "subnetwork")}"
    access_config = {}
  }

  tags = ["${format("web%02d", count.index+1)}"]
}
