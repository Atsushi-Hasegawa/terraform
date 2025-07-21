variable "service" {
  type = string
}
variable "env" {
  type = string
}
variable "ami" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "num" {
  type = number
}
variable "encrypted" {
  type = bool
}
variable "device_name" {
  type = string
}
variable "subnet_id" {
  type = list(string)
}
