variable "container_name" {}
variable "container_node_pool_name" {}
variable "node_count" {}

resource "google_container_cluster" "container-cluster" {
  name = "${var.container_name}"
  zone = "${var.zone}"
  initial_node_count = "${var.node_count}"
}

resource "google_container_node_pool" "container-np" {
  name = "${var.container_node_pool_name}"
  zone = "${var.zone}"
  cluster = "${google_container_cluster.container-cluster.name}"
  node_count = "${google_container_cluster.container-cluster.initial_node_count}"
}
