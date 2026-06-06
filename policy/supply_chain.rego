package terraform.supply_chain

# 1. AWS Provider バージョンの厳密な固定
# プロジェクト全体で一貫性を保ち、予期せぬアップデートを防ぎます
deny[msg] {
	provider := input.configuration.provider_config.aws
	version := provider.version_constraint
	
	# ">=" や指定なしを禁止し、"~>" (互換範囲) または "=" (厳密) を推奨
	# ここでは簡易的に ">=" が含まれる場合に警告
	contains(version, ">=")
	msg := sprintf("AWS Provider version constraint '%s' is too loose. Use '~>' or '=' to pin the version.", [version])
}

# 2. 信頼できない Module ソースの禁止
# パブリックなレジストリを直接参照せず、組織で管理されたソース（GitHub Enterpriseなど）を推奨
allowed_module_sources := ["github.com/Atsushi-Hasegawa/", "./modules/"]

deny[msg] {
	module := input.configuration.root_module.module_calls[_]
	source := module.source
	
	# 許可されたソースリストのいずれにも合致しない場合
	matches := [s | s := allowed_module_sources[_]; contains(source, s)]
	count(matches) == 0
	msg := sprintf("Module '%s' uses an unauthorized source '%s'. Use internal modules or approved GitHub repositories.", [module.name, source])
}

# 3. 変数への機密情報ベタ書きチェック
# 変数名に password, secret, token, key が含まれ、かつデフォルト値が設定されている場合に検知
deny[msg] {
	variable := input.configuration.root_module.variables[_]
	
	# 機密情報を示唆する名前
	sensitive_pattern := ["password", "secret", "token", "key"]
	contains_sensitive_name := [p | p := sensitive_pattern[_]; contains(lower(variable.name), p)]
	count(contains_sensitive_name) > 0
	
	# default 値が設定されている (ベタ書き)
	variable.default_value != null
	msg := sprintf("Variable '%s' appears to contain a hardcoded secret in its default value. Use a secrets manager or environment variables.", [variable.name])
}
