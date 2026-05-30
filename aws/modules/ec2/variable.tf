variable "service" {}
variable "env" {}
variable "ami" {}
variable "instance_type" {}
variable "num" {}
variable "subnet_id" {}
variable "encrypted" {}
variable "device_name" {}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups to associate with the EC2 instances"
  default     = []
}
