resource "google_service_account" "storage_account" {
  account_id   = "${lookup(var.service_account, "account_id")}"
  display_name = "${lookup(var.service_account, "display_name")}"
}

resource "google_storage_bucket" "bucket" {
  name          = "${var.env}-${var.service}${lookup(var.storage, "name")}"
  location      = "${lookup(var.storage, "location")}"
  storage_class = "REGIONAL"
  force_destroy = true
}

resource "google_storage_bucket_iam_binding" "storage_binding" {
  depends_on = ["google_service_account.storage_account"]
  bucket     = "${google_storage_bucket.bucket.name}"
  role       = "roles/storage.admin"

  members = [
    "serviceAccount:${google_service_account.storage_account.email}",
  ]
}

resource "google_storage_bucket_iam_member" "storage_member" {
  depends_on = ["google_storage_bucket_iam_binding.storage_binding"]
  bucket     = "${google_storage_bucket.bucket.name}"
  role       = "roles/storage.admin"
  member     = "serviceAccount:${google_service_account.storage_account.email}"
}
