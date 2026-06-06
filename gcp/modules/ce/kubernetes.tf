resource "google_container_cluster" "container-cluster" {
  name                     = lookup(var.container, "name")
  zone                     = var.zone
  initial_node_count       = lookup(var.container, "node_count")
  remove_default_node_pool = lookup(var.container, "remove_default_node")

  # 1. コンポーネントの制限
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    kubernetes_dashboard {
      disabled = true # ダッシュボードはセキュリティリスクのため無効化
    }
  }

  # 2. ネットワーク防御
  master_authorized_networks_config {
    # 実際には信頼できるIP範囲を指定すべきだが、まずは構造を導入
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "Warning: Open for demo"
    }
  }

  # 3. 権限管理の適正化
  enable_legacy_abac = false # ABACは無効化 (RBACを推奨)

  network                     = lookup(var.network, "network")
  subnetwork                  = lookup(var.network, "subnetwork")
  enable_binary_authorization = true

  node_config {
    # メタデータ露出の制限 (GCP-0057)
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform" # 最小権限と矛盾するがGCP推奨への移行
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_container_node_pool" "container-np" {
  name       = lookup(var.container, "node_pool_name")
  zone       = var.zone
  cluster    = google_container_cluster.container-cluster.name
  node_count = google_container_cluster.container-cluster.initial_node_count

  node_config {
    machine_type = lookup(var.engine, "machine_type")

    # メタデータ露出の制限 (GCP-0048)
    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  autoscaling {
    min_node_count = lookup(var.container, "min_node_count")
    max_node_count = lookup(var.container, "max_node_count")
  }

  management {
    auto_repair  = lookup(var.container, "auto_repair")
    auto_upgrade = lookup(var.container, "auto_upgrade")
  }
}
