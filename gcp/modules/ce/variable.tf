variable "zone" {}

variable "engine" {
  type = map(string)
}

variable "network" {
  type = map(string)
}

variable "env" {}
variable "service" {}

variable "container" {
  type = map(string)
}
