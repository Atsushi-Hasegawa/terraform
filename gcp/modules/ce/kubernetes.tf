resource "google_container_cluster" "container-cluster" {
  name                     = "${lookup(var.container, "name")}"
  zone                     = "${var.zone}"
  initial_node_count       = "${lookup(var.container, "node_count")}"
  remove_default_node_pool = "${lookup(var.container, "remove_default_node")}"

  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }

    kubernetes_dashboard {
      disabled = false
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  network                     = "${lookup(var.network, "network")}"
  subnetwork                  = "${lookup(var.network, "subnetwork")}"
  enable_binary_authorization = "${lookup(var.container, "enable_binary_authorization")}"
  enable_legacy_abac          = "${lookup(var.container, "enable_legacy_abac")}"

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/bigquery",
    ]
  }
}

resource "google_container_node_pool" "container-np" {
  name       = "${lookup(var.container, "node_pool_name")}"
  zone       = "${var.zone}"
  cluster    = "${google_container_cluster.container-cluster.name}"
  node_count = "${google_container_cluster.container-cluster.initial_node_count}"

  node_config {
    machine_type = "${lookup(var.engine, "machine_type")}"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/bigquery",
    ]
  }

  autoscaling {
    min_node_count = "${lookup(var.container, "min_node_count")}"
    max_node_count = "${lookup(var.container, "max_node_count")}"
  }

  management {
    auto_repair  = "${lookup(var.container, "auto_repair")}"
    auto_upgrade = "${lookup(var.container, "auto_upgrade")}"
  }
}
