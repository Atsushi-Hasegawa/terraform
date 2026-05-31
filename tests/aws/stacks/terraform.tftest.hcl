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
    vpc_id     = "vpc-99999"
    subnet_ids = ["subnet-11111", "subnet-22222"]
    app_sg_id  = "sg-app-123"
    alb_sg_id  = "sg-alb-456"
  }

  # 1. コンピュート層の検証
  assert {
    condition     = module.app.instance_count == 2
    error_message = "EC2 instance count mismatch in stack"
  }

  # 2. ネットワーク/DIの整合性
  assert {
    condition     = contains(tolist(module.app.vpc_security_group_ids), "sg-app-123")
    error_message = "DI Failure: Security Group sg-app-123 was not correctly passed to EC2"
  }

  # 3. ALB/ターゲットグループの整合性
  assert {
    condition     = module.app-lb.vpc_id == "vpc-99999"
    error_message = "DI Failure: VPC ID was not correctly passed to Target Group"
  }

  # 4. ネーミング・タグ
  assert {
    condition     = module.app.instance_tags[1]["Name"] == "web02"
    error_message = "Naming convention violation"
  }
}
