package terraform.lifecycle

# 1. 重大なリソースにおける削除保護の徹底
# KMSキーや特定のデータベースなど、削除されると復旧が困難なリソースを対象とします
deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_kms_key"
	
	# KMSキーの待機期間 (pending_window_in_days) が短すぎる場合に警告
	# デフォルトは30日だが、短く設定されているとリスク
	after := resource.change.after
	after.pending_window_in_days < 30
	msg := sprintf("KMS Key '%s' has a short pending window (%v days). Minimum 30 days is recommended to prevent accidental permanent data loss.", [resource.name, after.pending_window_in_days])
}

# 2. 非推奨・脆弱なエンジンバージョンの使用禁止 (RDS/Aurora)
# 例として、すでにサポートが終了している、または脆弱性が知られている古いバージョンをブロックします
deprecated_versions := ["5.6", "5.7.10"] # プロジェクトの基準に合わせて更新

deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_db_instance"
	engine_version := resource.change.after.engine_version
	
	count({v | v := deprecated_versions[_]; startswith(engine_version, v)}) > 0
	msg := sprintf("RDS instance '%s' uses a deprecated or vulnerable engine version '%s'. Please upgrade to a supported version.", [resource.name, engine_version])
}

# 3. 自動マイナーバージョンアップグレードの強制
# セキュリティパッチが自動的に適用されるようにします
deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_db_instance"
	
	not resource.change.after.auto_minor_version_upgrade
	msg := sprintf("RDS instance '%s' must have 'auto_minor_version_upgrade' enabled for automatic security patching.", [resource.name])
}

# 4. パブリックIPを持つEC2のライフサイクル警告
# 公開されているリソースは、変更時に特に注意が必要
deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_instance"
	resource.change.after.associate_public_ip_address == true
	
	# 変更アクションが "replace" (破壊と再作成) を含む場合
	actions := resource.change.actions[_]
	actions == "replace"
	
	msg := sprintf("Warning: Public EC2 instance '%s' will be REPLACED. This will change its public IP and may cause downtime/DNS issues.", [resource.name])
}
