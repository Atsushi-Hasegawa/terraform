# ECS Task Definition with FireLens (Fluent Bit)
resource "aws_ecs_task_definition" "this" {
  family                   = format("%s-%s", var.service, var.env)
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = var.image
      readonlyRootFilesystem = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "ssm-log"
          containerPath = "/var/log/amazon"
          readOnly      = false
        },
        {
          sourceVolume  = "ssm-lib"
          containerPath = "/var/lib/amazon"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name   = "cloudwatch"
          region = "ap-northeast-1" # 必要に応じて変数化
          log_group_name = aws_cloudwatch_log_group.ecs_service_log.name
          log_stream_prefix = "app"
        }
      }
    },
    {
      name  = "log_router"
      image = "amazon/aws-for-fluent-bit:stable"
      firelensConfiguration = {
        type = "fluentbit"
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.firelens_log.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "firelens"
        }
      }
      memoryReservation = 50
    }
  ])

  volume {
    name = "ssm-log"
  }

  volume {
    name = "ssm-lib"
  }
}

# ECS Service with ECS Exec enabled for troubleshooting
resource "aws_ecs_service" "this" {
  name                   = format("%s-%s-service", var.service, var.env)
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true # ECS Execを有効化 (トラブルシューティング用)

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.security_group_id]
    assign_public_ip = true # 必要に応じて変更
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = "app"
      container_port   = var.container_port
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}