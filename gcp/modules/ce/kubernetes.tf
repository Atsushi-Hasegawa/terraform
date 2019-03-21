resource "google_container_cluster" "container-cluster" {
  name               = "${lookup(var.container, "name")}"
  zone               = "${var.zone}"
  initial_node_count = "${lookup(var.container, "node_count")}"

  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = true
    }
  }

  network    = "${lookup(var.network, "network")}"
  subnetwork = "${lookup(var.network, "subnetwork")}"
}

resource "google_container_node_pool" "container-np" {
  name       = "${lookup(var.container, "node_pool_name")}"
  zone       = "${var.zone}"
  cluster    = "${google_container_cluster.container-cluster.name}"
  node_count = "${google_container_cluster.container-cluster.initial_node_count}"

  node_config {
    machine_type = "${lookup(var.engine, "machine_type")}"
  }
}
