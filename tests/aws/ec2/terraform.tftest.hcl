mock_provider "aws" {}

run "instance" {
  module {
    source = "../../../aws/modules/ec2"
  }

  variables {
    service       = "project"
    env           = "test"
    ami           = "ami-12345678"
    instance_type = "t3.micro"
    num           = 2
    subnet_id     = ["subnet-12345678", "subnet-87654321"]
    encrypted     = true
    device_name   = "mock-web"
  }
  # インスタンス数チェック
  assert {
    condition     = length(output.instance) == 2
    error_message = "Expected 2 EC2 instances to be created"
  }
  # ElasticIP数チェック
  assert {
    condition     = length(output.elastic_ip) == 2
    error_message = "Expected 2 EIPs associated with EC2 instances"
  }
  # EBS 暗号化チェック（すべてのブロックに対して）
  assert {
    condition = alltrue([
      for dev in tolist(output.instance[0].ebs_block_device) : dev.encrypted == true
    ])
    error_message = "EBS volumes on instance[0] are not all encrypted"
  }
  # Name タグチェック（web01, web02）
  assert {
    condition = alltrue([
      for i, inst in tolist(output.instance) :
      inst.tags["Name"] == format("web%02d", i + 1)
    ])
    error_message = "EC2 instance Name tag is not correctly formatted"
  }
}
