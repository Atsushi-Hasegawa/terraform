package terraform.deny

# 外部ファイルからインポート（デフォルトで "data" にマウントされる）
import data.encrypted_resources

# 1. 暗号化チェック (既存)
deny[msg] {
	change := input.resource_changes[_]
	resource_type = change.type
	encrypted_resources[resource_type]
	attr := encrypted_resources[resource_type]
	after := change.change.after

	not attr[after]
	msg := sprintf("Resource '%s' of type '%s' is missing encryption: '%s'", [change.name, resource_type, attr])
}

# 2. EC2 IMDS v2 必須チェック
deny[msg] {
	change := input.resource_changes[_]
	change.type == "aws_instance"
	
	tokens := change.change.after.metadata_options[_].http_tokens
	tokens != "required"
	
	msg := sprintf("EC2 instance '%s' must require IMDS v2 (http_tokens = 'required')", [change.name])
}

# 3. S3 Public Access Block 必須チェック
deny[msg] {
	change := input.resource_changes[_]
	change.type == "aws_s3_bucket"
	
	# バケット自体に公開設定がある場合の警告
	change.change.after.acl == "public-read"
	msg := sprintf("S3 bucket '%s' has public-read ACL. This is prohibited.", [change.name])
}