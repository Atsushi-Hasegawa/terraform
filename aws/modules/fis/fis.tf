################################################################################
# ECS Failure
################################################################################
resource "aws_fis_experiment_template" "ecs_stop_task" {
  for_each    = { for ecs in var.fis.ecs : ecs.service_name => ecs }
  description = "FIS Experiment Template to stop ECS tasks"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "stop-ecs-tasks"
    action_id = "aws:ecs:stop-task"
    target {
      key   = "Tasks"
      value = "ecs-tasks-target"
    }
  }

  target {
    name           = "ecs-tasks-target"
    resource_type  = "aws:ecs:task"
    selection_mode = each.value.selection_mode
    parameters = {
      cluster = each.value.cluster_name
      service = each.value.service_name
    }
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
# EC2 Failure
################################################################################
resource "aws_fis_experiment_template" "ec2_stop_instance" {
  count       = length(var.fis.ec2) > 0 ? 1 : 0
  description = "FIS Experiment Template to stop EC2 instances"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "stop-instances"
    action_id = "aws:ec2:stop-instances"
    parameter {
      key   = "startInstancesAfterDuration"
      value = "PT1M"
    }
    target {
      key   = "Instances"
      value = "ec2-instances-target"
    }
  }

  target {
    name           = "ec2-instances-target"
    resource_type  = "aws:ec2:instance"
    selection_mode = var.fis.ec2[0].selection_mode
    resource_arns  = [for id in var.fis.ec2[0].instance_ids : "arn:aws:ec2:*:*:instance/${id}"]
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
# API Error Injection
################################################################################
resource "aws_fis_experiment_template" "api_fault" {
  count       = length(var.fis.api_fault) > 0 ? 1 : 0
  description = "AWS Control Plane API Error Injection"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "inject-api-error"
    action_id = "aws:fis:inject-api-error"
    parameter {
      key   = "serviceAbbreviation"
      value = var.fis.api_fault[0].service
    }
    parameter {
      key   = "operationName"
      value = var.fis.api_fault[0].operation_name
    }
    parameter {
      key   = "errorCode"
      value = var.fis.api_fault[0].error_code
    }
    parameter {
      key   = "percentage"
      value = tostring(var.fis.api_fault[0].percentage)
    }
  }

  target {
    name           = "target-role"
    resource_type  = "aws:iam:role"
    resource_arns  = [aws_iam_role.fis.arn]
    selection_mode = "ALL"
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
# Network Advanced (Latency/Loss/Jitter)
################################################################################
resource "aws_fis_experiment_template" "network_advanced" {
  count       = length(var.fis.network_advanced) > 0 ? 1 : 0
  description = "Advanced Network Impairment via SSM"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "inject-network-impairment"
    action_id = "aws:ssm:send-command"
    parameter {
      key   = "documentArn"
      value = "arn:aws:ssm:*:*:document/AWSFIS-Run-Network-Latency"
    }
    parameter {
      key = "documentParameters"
      value = jsonencode({
        duration = var.fis.network_advanced[0].duration
        loss     = var.fis.network_advanced[0].loss
        jitter   = var.fis.network_advanced[0].jitter
      })
    }
    target {
      key   = "Instances"
      value = "network-target-instances"
    }
  }

  target {
    name           = "network-target-instances"
    resource_type  = "aws:ec2:instance"
    selection_mode = var.fis.network_advanced[0].selection_mode
    resource_arns  = [for id in var.fis.network_advanced[0].instance_ids : "arn:aws:ec2:*:*:instance/${id}"]
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
# Storage (EBS I/O Pause)
################################################################################
resource "aws_fis_experiment_template" "ebs_fault" {
  count       = length(var.fis.ebs_fault) > 0 ? 1 : 0
  description = "EBS I/O Pause"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "pause-io"
    action_id = "aws:ebs:pause-volume-io"
    parameter {
      key   = "duration"
      value = var.fis.ebs_fault[0].duration
    }
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
# Observability Disruption
################################################################################
resource "aws_fis_experiment_template" "observability_disruption" {
  count       = length(var.fis.observability_disruption) > 0 ? 1 : 0
  description = "Block Observability Traffic"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "block-observability"
    action_id = "aws:ssm:send-command"
    parameter {
      key   = "documentArn"
      value = "arn:aws:ssm:*:*:document/AWSFIS-Run-Network-Blackhole"
    }
    parameter {
      key = "documentParameters"
      value = jsonencode({
        duration = var.fis.observability_disruption[0].duration
      })
    }
    target {
      key   = "Instances"
      value = "obs-target-instances"
    }
  }

  target {
    name           = "obs-target-instances"
    resource_type  = "aws:ec2:instance"
    selection_mode = var.fis.observability_disruption[0].selection_mode
    resource_arns  = [for id in var.fis.observability_disruption[0].instance_ids : "arn:aws:ec2:*:*:instance/${id}"]
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
# ECS Network Fault (Latency / Blackhole)
################################################################################
resource "aws_fis_experiment_template" "ecs_network_fault" {
  count       = length(var.fis.ecs_network_fault) > 0 ? 1 : 0
  description = "ECS Network Fault Injection"
  role_arn    = aws_iam_role.fis.arn

  action {
    name      = "network-fault"
    action_id = "aws:ssm:send-command"
    parameter {
      key   = "documentArn"
      value = var.fis.ecs_network_fault[0].fault_type == "latency" ? "arn:aws:ssm:*:*:document/AWSFIS-Run-Network-Latency" : "arn:aws:ssm:*:*:document/AWSFIS-Run-Network-Blackhole"
    }
    parameter {
      key = "documentParameters"
      value = jsonencode({
        duration = var.fis.ecs_network_fault[0].duration
      })
    }
    target {
      key   = "Tasks"
      value = "ecs-tasks-target"
    }
  }

  target {
    name           = "ecs-tasks-target"
    resource_type  = "aws:ecs:task"
    selection_mode = var.fis.ecs_network_fault[0].selection_mode
    parameters = {
      cluster = var.fis.ecs_network_fault[0].cluster_name
      service = var.fis.ecs_network_fault[0].service_name
    }
  }

  dynamic "stop_condition" {
    for_each = var.fis.stop_alarms
    content {
      source = "aws:cloudwatch:alarm"
      value  = stop_condition.value
    }
  }
}
