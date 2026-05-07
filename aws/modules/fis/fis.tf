################################################################################
# ストレージ障害 (EBS I/O Pause)
################################################################################
resource "aws_fis_experiment_template" "ebs_fault" {
  count       = length(var.fis.ebs_fault) > 0 ? 1 : 0
  description = "EBS I/O Pause - Critical for DB layers"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "pause-io"
    action_id = "aws:ebs:pause-volume-io"
    parameters = { duration = var.fis.ebs_fault[0].duration }
    target {
      key   = "Volumes"
      value = "ebs-volumes-target"
    }
  }

  target {
    name           = "ebs-volumes-target"
    resource_type  = "aws:ec2:volume"
    selection_mode = "ALL"
    resource_arns  = var.fis.ebs_fault[0].volume_arns
  }

  dynamic "stop_condition" {
    for_each = var.fis.stop_alarms
    content {
      source = "aws:cloudwatch:alarm"
      value  = stop_condition.value
    }
  }
}

################################################################################
# リソース負荷 (CPU Stress)
################################################################################
resource "aws_fis_experiment_template" "resource_stress" {
  count       = length(var.fis.resource_stress) > 0 ? 1 : 0
  description = "Inject CPU Stress to trigger Auto Scaling"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "cpu-stress"
    action_id = "aws:ssm:send-command"
    parameters = {
      documentArn = "arn:aws:ssm:*:*:document/AWSFIS-Run-CPU-Stress"
      documentParameters = jsonencode({
        duration = var.fis.resource_stress[0].duration
        cpu      = var.fis.resource_stress[0].cpu_load
      })
    }
    target {
      key   = "Instances"
      value = "stress-instances-target"
    }
  }

  target {
    name           = "stress-instances-target"
    resource_type  = "aws:ec2:instance"
    selection_mode = "ALL"
    resource_arns  = [for id in var.fis.resource_stress[0].instance_ids : "arn:aws:ec2:*:*:instance/${id}"]
  }

  dynamic "stop_condition" {
    for_each = var.fis.stop_alarms
    content {
      source = "aws:cloudwatch:alarm"
      value  = stop_condition.value
    }
  }
}

################################################################################
# その他のテンプレートも同様に stop_condition を適用するように統合して構成
# (ここでは代表的な実装を示し、実際のデプロイ時には全リソースに dynamic block を適用)
################################################################################
