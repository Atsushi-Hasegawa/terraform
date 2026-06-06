package terraform.network_perimeter

# 1. CloudFront における WAF の強制
deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_cloudfront_distribution"
	
	# web_acl_id が設定されていない、または空文字列の場合
	after := resource.change.after
	not after.web_acl_id
	msg := sprintf("CloudFront distribution '%s' must have a WAF Web ACL associated (web_acl_id is missing).", [resource.name])
}

# 2. ALB における WAF の強制
# 注: ALBとWAFの紐付けは aws_wafv2_web_acl_association リソースで行われるため、
# そのリソースが存在するかどうかをチェックするロジックが必要（ここでは簡易的にリソースタイプの存在を確認）
deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_lb"
	resource.change.after.load_balancer_type == "application"
	resource.change.after.internal == false
	
	# 同一プラン内に association リソースがあるかチェック
	associations := [r | r := input.resource_changes[_]; r.type == "aws_wafv2_web_acl_association"]
	count(associations) == 0
	msg := sprintf("Public ALB '%s' must be associated with a WAF Web ACL.", [resource.name])
}

# 3. 管理ポート (SSH/RDP) の全開放禁止
dangerous_ports := [22, 3389]

deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_security_group_rule"
	resource.change.after.type == "ingress"
	
	# ポートのチェック
	port := resource.change.after.from_port
	count({p | p := dangerous_ports[_]; p == port}) > 0
	
	# 接続元のチェック (0.0.0.0/0 が含まれているか)
	cidrs := resource.change.after.cidr_blocks[_]
	cidrs == "0.0.0.0/0"
	
	msg := sprintf("Security group rule in '%s' allows access to port %v from 0.0.0.0/0. Limit access to trusted IPs.", [resource.name, port])
}

# 4. デフォルトVPC利用の制限 (明示的な設定の推奨)
deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_instance"
	
	# subnet_id が指定されていない場合、デフォルトVPCに配置される可能性がある
	not resource.change.after.subnet_id
	msg := sprintf("EC2 instance '%s' is missing an explicit subnet_id. Deployment to default VPC is prohibited.", [resource.name])
}
