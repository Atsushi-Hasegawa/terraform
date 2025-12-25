resource "aws_fis_experiment_template" "ecs_stop_task" {
  for_each    = { for ecs in var.fis.ecs : ecs.service_name => ecs }
  description = "FIS Experiment Template to stop ECS tasks in cluster ${each.value.cluster_name}"
  role_arn    = aws_iam_role.fis.arn

  action {
    name        = "stop-ecs-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "Stop ECS tasks"
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

  stop_condition {
    source = "none"
  }

  tags = {
    Name        = format("%s-%s-ecs-stop-task", var.project, var.environment)
    Environment = var.environment
  }
}