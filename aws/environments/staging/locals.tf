locals {
  project = {
    service = "my-app"
    env     = "staging"
    region  = "ap-northeast-1"
  }

  common_tags = {
    Project     = local.project.service
    Environment = local.project.env
    ManagedBy   = "Terraform"
  }
}
