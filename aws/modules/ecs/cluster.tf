resource "aws_ecs_cluster" "this" {
  name = var.cluster_name != null ? var.cluster_name : format("%s-%s-cluster", var.service, var.env)

  setting {
    name  = "container_insights"
    value = var.container_insights
  }

  tags = {
    Name        = var.cluster_name != null ? var.cluster_name : format("%s-%s-cluster", var.service, var.env)
    Environment = var.env
    Service     = var.service
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
