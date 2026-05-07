variable "env" {}
variable "service" {}

variable "storage" {
  type = map(string)
}

variable "service_account" {
  type = map(string)
}
