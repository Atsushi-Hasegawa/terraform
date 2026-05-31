mock_provider "aws" {}

run "ec2_module_security_and_standard_compliance" {
  command = plan

  module {
    source = "../../../aws/modules/ec2"
  }

  variables {
    service            = "compliance-test"
    env                = "prod"
    ami                = "ami-98765432"
    instance_type      = "m5.large"
    num                = 3
    subnet_id          = ["sn-1", "sn-2", "sn-3"]
    encrypted          = true
    device_name        = "/dev/xvda"
    security_group_ids = ["sg-secure"]
  }

  # セキュリティ: パブリックIPの禁止
  assert {
    condition     = aws_instance.app[0].associate_public_ip_address == false
    error_message = "EC2 instance should not have a public IP associated"
  }

  # セキュリティ: すべてのEBSボリュームの暗号化強制
  assert {
    condition = alltrue([
      for device in tolist(aws_instance.app[0].ebs_block_device) : device.encrypted == true
    ])
    error_message = "EBS volumes must be encrypted in production environments"
  }

  # 構成: インスタンスサイズの整合性
  assert {
    condition     = aws_instance.app[0].instance_type == "m5.large"
    error_message = "Instance type does not match requested configuration"
  }

  # 構成: 命名規則の遵守 (web01, web02, web03)
  assert {
    condition     = aws_instance.app[2].tags["Name"] == "web03"
    error_message = "Naming convention for instances is not being followed"
  }
}
