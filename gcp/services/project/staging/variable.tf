variable "project" {}
variable "region" {}

provider "google" {
  credentials = "${file("../config/account.json")}"
  project     = "${var.project}"
  region      = "${var.region}"
}

variable zone {
  default = "asia-northeast1-a"
}

variable "firewall" {
  type = "list"

  default = [
    {
      name = "allow-http"
      tag  = "http"
      port = 80
      ip   = "192.168.0.0/20"
    },
    {
      name = "allow-https"
      tag  = "https"
      port = 443
      ip   = "192.168.0.0/20"
    },
    {
      name = "alllow-ssh"
      tag  = "ssh"
      port = 22
      ip   = "0.0.0.0/0"
    },
  ]
}

variable "network" {
  default = {
    vpc_name              = "network"
    subnetwork_name       = "subnetwork"
    subnetwork_cidr_range = "192.168.0.0/20"
  }
}

variable "compute_engine" {
  default = {
    count         = 2
    instance_name = "test-compute"
    machine_type  = "n1-standard-1"
    image         = "ubuntu-os-cloud/ubuntu-1804-lts"
    size_gb       = 10
    type          = "pd-standard"
  }
}

variable "container" {
  default = {
    name           = "test-container"
    node_pool_name = "test-container-np"
    node_count     = 1
  }
}

variable "storage" {
  default = {
    name     = "storage"
    location = "asia-northeast1"
  }
}

variable "service_account" {
  default = {
    account_id   = "storage-account"
    display_name = "storage-account"
  }
}

variable "redis" {
  default = {
    name                    = "redis"
    tier                    = "STANDARD_HA"
    memory_size_gb          = 1
    location_id             = "asia-northeast1-a"
    alternative_location_id = "asia-northeast1-b"
    version                 = "REDIS_3_2"

    //インタスタンスの予約ip範囲を設定(subnetworkのcidr範囲のため192.168.0.0/20以外)
    reserved_ip_range = "10.0.0.0/29"
  }
}
