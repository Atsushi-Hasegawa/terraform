# ECS Task Execution Role (For ECS Agent)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = format("%s-%s-ecs-task-execution-role", var.service, var.env)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = format("%s-%s-ecs-task-execution-role", var.service, var.env)
    Environment = var.env
  }
}

# Attach Standard ECS Execution Policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (For Application)
resource "aws_iam_role" "ecs_task_role" {
  name = format("%s-%s-ecs-task-role", var.service, var.env)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = format("%s-%s-ecs-task-role", var.service, var.env)
    Environment = var.env
  }
}

# Add permissions for ECS Exec (Optional but recommended for troubleshooting)
resource "aws_iam_policy" "ecs_exec_policy" {
  name        = format("%s-%s-ecs-exec-policy", var.service, var.env)
  description = "Allows ECS Exec to connect to the container"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_exec_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
}

output "execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}
