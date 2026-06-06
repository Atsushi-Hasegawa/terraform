package terraform.governance

# 1. 必須タグのチェック (Project, Environment)
mandatory_tags := ["Project", "Environment"]

deny[msg] {
	resource := input.resource_changes[_]
	resource.mode == "managed"
	tags := resource.change.after.tags
	
	missing := {tag | tag := mandatory_tags[_]; not tags[tag]}
	count(missing) > 0
	msg := sprintf("Resource '%s' is missing mandatory tags: %v", [resource.name, missing])
}

# 2. リージョン制限 (東京リージョンのみ許可)
allowed_regions := ["ap-northeast-1"]

deny[msg] {
	# terraform config から provider の region をチェック
	# または、リソースの ARN や属性から類推 (ここでは provider 設定を想定)
	provider := input.configuration.provider_config.aws
	region := provider.expressions.region.constant_value
	
	not count({r | r := allowed_regions[_]; r == region}) > 0
	msg := sprintf("Region '%s' is not allowed. Only %v are permitted.", [region, allowed_regions])
}

# 3. S3 サーバーアクセスログの必須化
deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_s3_bucket"
	
	# ログ出力先バケット自体は除外（循環参照防止）
	not contains(resource.name, "log")
	
	# logging 設定の有無をチェック
	# 注: Terraform のバージョンやリソースタイプによって属性名が異なる場合があるため、
	# 実際のリソース定義に合わせて調整が必要
	not resource.change.after.logging
	msg := sprintf("S3 bucket '%s' must have server access logging enabled.", [resource.name])
}
