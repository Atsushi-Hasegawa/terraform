package terraform.deny

# 外部ファイルからインポート（デフォルトで "data" にマウントされる）
import data.encrypted_resources

deny[msg] {
	change := input.resource_changes[_]
	resource_type = change.type
	encrypted_resources[resource_type]
	attr := encrypted_resources[resource_type]
	after := change.change.after

	not attr[after]
	msg := sprintf("Resource '%s' of type '%s' is missing encryption: '%s'", [change.name, resource_type, attr])
}