variable "instance_name" {}
variable "machine_type" {}
variable "zone" {}
variable "image" {}
variable "size_gb" {}
variable "network" {}
variable "subnetwork" {}
variable "env" {}
variable "service" {}

resource "google_compute_instance" "compute-instance" {
  name = "${var.instance_name}"
  machine_type = "${var.machine_type}"
  zone  = "${var.zone}"

  boot_disk {
    initialize_params {
      size = "${var.size_gb}"
      type = "pd-standard"
      image = "${var.image}"
    }
  }

  network_interface = {
    //network = "${var.network}"
    subnetwork = "${var.subnetwork}"
    access_config = {}
  }
}
