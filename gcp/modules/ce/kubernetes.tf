variable "container" {
  type = "map"
}

resource "google_container_cluster" "container-cluster" {
  name               = "${lookup(var.container, "name")}"
  zone               = "${var.zone}"
  initial_node_count = "${lookup(var.container, "node_count")}"

  network    = "${lookup(var.network, "network")}"
  subnetwork = "${lookup(var.network, "subnetwork")}"
}

resource "google_container_node_pool" "container-np" {
  name       = "${lookup(var.container, "node_pool_name")}"
  zone       = "${var.zone}"
  cluster    = "${google_container_cluster.container-cluster.name}"
  node_count = "${google_container_cluster.container-cluster.initial_node_count}"
}
