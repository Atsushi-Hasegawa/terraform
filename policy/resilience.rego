package terraform.resilience

# 1. RDS 削除保護の強制 (ランサムウェア/誤操作対策)
deny[msg] {
	change := input.resource_changes[_]
	change.type == "aws_db_instance"
	not change.change.after.deletion_protection
	msg := sprintf("RDS instance '%s' must have deletion_protection enabled.", [change.name])
}

# 2. S3 Object Lock (不変バックアップ) の強制
# バックアップ用途とみなされるバケット（名前にbackupが含まれる等）に適用
deny[msg] {
	change := input.resource_changes[_]
	change.type == "aws_s3_bucket"
	contains(change.name, "backup")
	not change.change.after.object_lock_enabled
	msg := sprintf("Backup S3 bucket '%s' must have Object Lock enabled for Ransomware resilience.", [change.name])
}

# 3. セキュリティグループの横展開防止 (広い内部許可の禁止)
deny[msg] {
	change := input.resource_changes[_]
	change.type == "aws_security_group_rule"
	change.change.after.type == "ingress"
	
	# 内部ネットワーク(10.0.0.0/8等)であっても全ポート(0-65535)許可は禁止
	change.change.after.from_port == 0
	change.change.after.to_port == 65535
	msg := sprintf("Security group rule in '%s' allows all ports. This enables lateral movement.", [change.name])
}
