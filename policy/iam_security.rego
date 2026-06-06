package terraform.iam

# 1. Action: "*" の禁止 (最小権限)
deny[msg] {
	change := input.resource_changes[_]
	change.type == "aws_iam_policy"
	doc := json.unmarshal(change.change.after.policy)
	statement := doc.Statement[_]
	
	statement.Effect == "Allow"
	statement.Action == "*"
	msg := sprintf("IAM Policy '%s' allows Action: '*'. Use least privilege.", [change.name])
}

# 2. 権限昇格リスク (PassRole + EC2/Lambda/ECS実行権限)
dangerous_actions := ["iam:PassRole", "iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion"]

deny[msg] {
	change := input.resource_changes[_]
	change.type == "aws_iam_policy"
	doc := json.unmarshal(change.change.after.policy)
	statement := doc.Statement[_]
	
	count({x | x := statement.Action[_]; x == dangerous_actions[_]}) > 0
	statement.Resource == "*"
	msg := sprintf("IAM Policy '%s' contains dangerous escalation actions with Resource: '*'.", [change.name])
}
