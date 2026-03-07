variable "env" {}
variable "service" {}
variable "vpc_cidr" {}
variable "subnets" {
  type = list(string)
}
variable "availability_zones" {
  type = list(string)
}
variable "rds_port" {
  type    = number
  default = 3306
}

variable "container_port" {
  type    = number
  default = 80
}
variable "enable_databricks_federated" {
  type    = bool
  default = false
}
