# Stack-Driven Architecture Patterns

## Directory Structure
インフラの「設計図」と「設定値」を物理的に分離します。

```text
aws/
├── modules/          # 原子的なリソース定義 (VPC, EC2, RDS等)
├── stacks/           # Terraform実行ディレクトリ。リソースの組み合わせと参照ロジック(Data Source)を記述。
└── environments/     # 設定値(.tfvars)のみを管理。ロジック(.tf)は置かない。
```

## File Responsibilities (within Stacks)
各スタックディレクトリは以下の 5 つのファイルで構成します。

1. **main.tf**: リソースの組み立て。Provider定義と Data Source（参照）もここに含める。
2. **variables.tf**: 外部入力の定義。必ず `type`（Object型推奨）と `description` を含める。
3. **locals.tf**: 内部計算、タグの定義、固定値の管理。
4. **outputs.tf**: 他の層やテストから参照するための出力インターフェース。
5. **versions.tf**: Terraform (>v1.15.0) および Provider (>v6.47.0) のバージョン固定。

## Dependency Injection (DI) Pattern
スタック間は Data Source を用いて疎結合に繋ぎます。
- **Tag-based Search**: `common` 基盤には `FoundationLayer = "true"` などのタグを付与し、他のスタックからそのタグをキーに検索・取得する。
- **Variable Injection**: スタック自体は `vpc_id` などを外から受け取れるように設計し、`environments` の設定（または実行時の探索結果）を注入する。
