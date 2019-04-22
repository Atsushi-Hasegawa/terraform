resource "google_bigquery_dataset" "bigquery-dataset" {
  dataset_id                  = "${lookup(var.bigquery, "dataset_id")}"
  location                    = "${lookup(var.bigquery, "location")}"
  default_table_expiration_ms = 3600000
}

resource "google_bigquery_table" "bigquery-table" {
  dataset_id = "${google_bigquery_dataset.bigquery-dataset.dataset_id}"
  table_id   = "${lookup(var.bigquery, "table_id")}"

  time_partitioning {
    type = "DAY"
  }

  schema = "${file("${path.module}/config/schema.json")}"
}
