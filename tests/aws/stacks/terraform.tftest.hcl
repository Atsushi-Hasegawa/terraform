mock_provider "aws" {
  alias = "mock"
}

run "validate_application_stack_integration" {
  command = plan

  module {
    source = "../../../aws/stacks/application"
  }

  providers = {
    aws = aws.mock
  }

  variables {
    region = "ap-northeast-1"
    certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/test"
    project = {
      service = "test-service"
      env     = "test"
    }
    ec2_config = {
      ami           = "ami-12345678"
      instance_type = "t3.micro"
      count         = 2
      encrypted     = true
      device_name   = "/dev/sda1"
    }
    lb_config = {
      target_group_name = "test-tg"
    }
    # vpc_id 等は data ソースで取得されるため、ここでは不要（モックが必要）
  }

  # 1. コンピュート層の検証
  assert {
    condition     = module.app.instance_count == 2
    error_message = "EC2 instance count mismatch in stack"
  }

  # 2. バックアップインフラの検証
  assert {
    condition     = module.backup.vault_name != ""
    error_message = "Backup vault was not initialized"
  }

  # 3. 命名・タグの検証 (EC2モジュールで付与されたタグ)
  assert {
    condition     = module.app.instance_tags[0]["BackupPolicy"] == "high-resilience"
    error_message = "EC2 BackupPolicy tag is missing"
  }
}
