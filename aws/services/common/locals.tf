locals {
  service = "common-base"
  env     = "common"
  
  common_tags = {
    Project     = "common-base"
    Environment = "common"
    ManagedBy   = "Terraform"
    Layer       = "foundation"
  }
}
