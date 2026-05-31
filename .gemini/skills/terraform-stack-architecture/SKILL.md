---
name: terraform-stack-architecture
description: Terraformの「Stack主導型・Environment設定分離」アーキテクチャに基づいて、AWSインフラを設計・構築・修正するための専門スキル。新しいリソースの追加や既存構成のリファクタリング時に使用します。
---

# Terraform Stack Architecture

このスキルは、インフラの「設計図（Stacks）」と「環境固有の設定（Environments）」を完全に分離し、保守性と拡張性を最大化するためのガイドラインを提供します。

## 核心となる原則
1. **ロジックは Stacks に**: リソースの作成、Data Source による参照、Provider 定義はすべて `aws/stacks/` 配下に集約します。
2. **設定は Environments に**: `aws/environments/` 配下には `.tfvars` ファイルのみを置き、環境ごとのパラメータ（リージョン、スペック等）を管理します。
3. **疎結合 (DI)**: スタック間は物理的な参照ではなく、タグを用いた Data Source 検索で接続します。

## ワークフロー

### 1. 新しい機能（スタック）の追加
1. `aws/stacks/<stack-name>/` を作成し、`main.tf`, `variables.tf`, `locals.tf`, `outputs.tf`, `versions.tf` を用意します。
2. 必要な情報を他のスタックから取得する場合は、`main.tf` 内で `data` ソースを定義します。
3. `aws/environments/<env>/terraform.tfvars` に、新スタックで必要な変数を追加します。

### 2. 変更の反映
リソースの操作は、常に対象のスタックディレクトリで行います。
```bash
cd aws/stacks/<stack-name>
terraform apply -var-file=../../environments/<env>/terraform.tfvars
```

### 3. テストの作成
`tests/aws/stacks/` 配下にスタック全体の統合テストを作成します。
- `mock_provider` を使用し、`command = plan` または `command = apply` で DI の整合性を検証します。

## 詳細リファレンス
- **アーキテクチャ詳細**: [references/architecture-patterns.md](references/architecture-patterns.md) を参照してください。
- **命名規則**: リソースの命名（web01, web02等）は既存の慣習に従ってください。
