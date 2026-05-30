variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_arn" {
  description = "ECS cluster ARN"
  type        = string
}

variable "fis" {
  type = object({
    # 基本項目
    ecs = list(object({ cluster_name = string, service_name = string, selection_mode = string }))
    ec2 = list(object({ instance_ids = list(string), selection_mode = string }))
    rds = list(object({ cluster_arns = list(string), selection_mode = string }))

    # ネットワーク・DNS
    network_advanced = list(object({
      instance_ids   = list(string)
      selection_mode = string
      duration       = string
      loss           = string
      jitter         = string
      dns_fault      = string
    }))

    # コントロールプレーン・セキュリティAPI (IAM/KMS/SecretsManager等)
    api_fault = list(object({
      service        = string
      operation_name = string
      error_code     = string
      percentage     = number
      duration       = string
    }))

    # ストレージ障害 (EBS I/O)
    ebs_fault = list(object({
      volume_arns = list(string)
      duration    = string
    }))

    # リソース負荷 (CPU/Memory Stress)
    resource_stress = list(object({
      instance_ids = list(string)
      duration     = string
      cpu_load     = number
    }))

    # ECS ネットワーク障害
    ecs_network_fault = list(object({
      cluster_name   = string
      service_name   = string
      selection_mode = string
      duration       = string
      fault_type     = string # "latency" or "blackhole"
    }))

    # 観測・連鎖・安全性
    observability_disruption = list(object({ instance_ids = list(string), selection_mode = string, duration = string, target_service = string }))
    chained_scenarios        = list(object({ name = string, instance_ids = list(string), duration = string }))
    stop_alarms              = list(string) # セーフティレール用のCloudWatchアラームARNリスト
  })
}
