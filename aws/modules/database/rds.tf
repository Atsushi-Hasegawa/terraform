resource "aws_db_subnet_group" "default" {
  name       = format("%s-subnet-group", var.environment)
  subnet_ids = var.subnet_ids

  tags = {
    Name        = format("%s-subnet-group", var.environment)
    Environment = var.environment
  }
}

resource "aws_rds_cluster" "base" {
  cluster_identifier                  = format("%s-%s", var.environment, var.database.name)
  engine                              = "aurora-mysql"
  engine_version                      = "8.0.mysql_aurora.3.05.2"
  database_name                       = var.database.name
  master_username                     = var.database.username
  manage_master_user_password         = true
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.aurora_cluster_param_group.name
  vpc_security_group_ids              = [var.rds_security_group_id]
  db_subnet_group_name                = aws_db_subnet_group.default.name
  skip_final_snapshot                 = false
  final_snapshot_identifier           = format("%s-%s-final-snapshot", var.environment, var.database.name)
  deletion_protection                 = true
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.rds.arn
  enabled_cloudwatch_logs_exports     = ["error", "general", "slowquery", "audit"]
  preferred_backup_window             = "03:00-04:00"
  backup_retention_period             = 35
  copy_tags_to_snapshot               = true
  iam_database_authentication_enabled = true

  # Performance Insights (Instance level, but here for reference if supported by cluster type or needs separate instance config)
  # Actually PI is configured at instance level, so moving to aws_rds_cluster_instance

  tags = {
    Name        = format("%s-%s", var.environment, var.database.name)
    Environment = var.environment
  }
}

resource "aws_iam_role" "rds_access_role" {
  name = format("%s-%s-rds-access-role", var.environment, var.database.name)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_rds_cluster_role_association" "rds_access_role_assoc" {
  db_cluster_identifier = aws_rds_cluster.base.id
  feature_name          = "" # Leave empty for all features or specify if needed
  role_arn              = aws_iam_role.rds_access_role.arn
}

resource "aws_rds_cluster_instance" "base" {
  count                   = var.instance_count
  identifier              = format("%s-%s-%02d", var.environment, var.database.name, count.index + 1)
  cluster_identifier      = aws_rds_cluster.base.id
  engine                  = aws_rds_cluster.base.engine
  engine_version          = aws_rds_cluster.base.engine_version
  instance_class          = var.database.instance_class
  db_parameter_group_name = aws_db_parameter_group.aurora_instance_param_group.name

  publicly_accessible = false
  ca_cert_identifier  = "rds-ca-rsa4096-g1" # Use the latest, high-security CA certificate

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  tags = {
    Name        = format("%s-%s-%02d", var.environment, var.database.name, count.index + 1)
    Environment = var.environment
  }
}

resource "aws_rds_cluster_parameter_group" "aurora_cluster_param_group" {
  name        = format("%s-%s-cluster-param-group", var.environment, var.database.name)
  family      = "aurora-mysql8.0"
  description = format("Cluster parameter group for %s with high security and performance settings", var.environment)

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  # --- Performance & Reliability ---

  # Ensure Row-based logging for best performance/consistency balance
  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  # Print all deadlocks to the error log for faster troubleshooting
  parameter {
    name  = "innodb_print_all_deadlocks"
    value = "1"
  }

  # --- Security & Audit Enhancements ---

  # Force SSL/TLS for all connections
  parameter {
    name         = "require_secure_transport"
    value        = "ON"
    apply_method = "immediate"
  }

  # Restrict TLS versions to 1.2 or higher
  parameter {
    name  = "tls_version"
    value = "TLSv1.2,TLSv1.3"
  }

  # Advanced Audit Logging
  parameter {
    name  = "server_audit_logging"
    value = "1"
  }

  parameter {
    name  = "server_audit_events"
    value = "CONNECT,QUERY,QUERY_DCL,QUERY_DDL,QUERY_DML,TABLE"
  }

  parameter {
    name  = "server_audit_incl_users"
    value = "" # Log all users including the master user
  }
}

resource "aws_db_parameter_group" "aurora_instance_param_group" {
  name        = format("%s-%s-instance-param-group", var.environment, var.database.name)
  family      = "aurora-mysql8.0"
  description = format("Instance parameter group for %s with performance monitoring", var.environment)

  # --- Performance Monitoring & Tuning ---

  # Enable Slow Query Log
  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  # Set long query time to 1 second to capture performance bottlenecks
  parameter {
    name  = "long_query_time"
    value = "1"
  }

  # Enable all InnoDB monitors for detailed Performance Insights metrics
  parameter {
    name  = "innodb_monitor_enable"
    value = "all"
  }

  parameter {
    name         = "max_connections"
    value        = "4000"
    apply_method = "pending-reboot"
  }

  tags = {
    Name        = format("%s-%s-instance-param-group", var.environment, var.database.name)
    Environment = var.environment
  }
}