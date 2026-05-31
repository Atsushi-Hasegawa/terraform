# Project Architecture & Knowledge Base

このドキュメントでは、本プロジェクトの Terraform 構成設計指針と、導入されている技術要素（Valkey等）に関する知見をまとめています。

## 1. Terraform 構成設計 (AWS)

### 階層構造と役割分離 (Stack-Driven Architecture)
本プロジェクトでは、インフラの「設計図（ロジック）」と「環境（設定値）」を完全に分離しています。

- **`aws/modules/`**: 原子的な単一リソースの定義（VPC, EC2 等）。
- **`aws/stacks/`**: **Terraform の実行ディレクトリ。** リソースの作成ロジック、および他のスタックからの情報取得（Data Source）を記述。
- **`aws/environments/`**: **設定値（.tfvars）のみを管理。** .tf ファイル（ロジック）は配置せず、環境ごとのスペックやリージョンのみを定義。

| レイヤー | ディレクトリ | 内容 |
| :--- | :--- | :--- |
| Blueprint | `aws/stacks/` | リソース作成、依存関係解決、Provider定義 |
| Config | `aws/environments/` | `terraform.tfvars` による環境パラメータの定義 |

### 依存性の注入 (DI) と 参照
スタック間の連携は、`environments` 側で行うのではなく、`stacks` 側で Data Source を用いて動的に行います。これにより、すべての環境で一貫した結合ロジックが保証されます。

### ファイル構成の標準化 (Stacks内)
各スタックディレクトリは以下の役割に基づいて 4 つのファイルに分割されています。

| ファイル名 | 役割 |
| :--- | :--- |
| `main.tf` | リソースの構成・組み立て (Blueprint) |
| `locals.tf` | 内部ロジック、タグ設定、固定値 (Internal Logic) |
| `variables.tf` | 外部からの入力、型定義 (Interface / Schema) |
| `outputs.tf` | 他の層への公開情報 (API / Public Interface) |
| `versions.tf` | Terraform および Provider のバージョン固定 |

---

## 2. 技術知見メモ

### Valkey / Redis 運用
Valkey（Redisフォーク）を導入・運用する際の重要ポイント。

#### 主要データ型と使い分け
- **Hash**: ユーザー属性など、構造化されたデータの保存。
- **Sorted Set (ZSET)**: ランキング、時系列データ、レートリミッター。
- **String (SETNX)**: 分散ロックの実装（アトミックな存在確認とセット）。

#### キャッシュ戦略
- **キャッシュ貫通対策**: DBに存在しないキーに対して「空オブジェクト」を短期間のTTL付きで保存する。
- **分散ロック**: `SET key value NX EX 30` のように、セットと期限設定を単一コマンドで行う（アトミック操作）。

#### セキュリティ設計
- Valkey へのアクセスは、ネットワーク全体 (CIDR) ではなく、**接続元アプリケーションのセキュリティグループ ID** を指定して許可する。

---

## 3. CLI 操作リファレンス

### Terraform 操作 (Stackの反映)
リソースを操作する際は、対象のスタックディレクトリに移動し、環境ごとの設定ファイルを指定して実行します。

```bash
# staging 環境のネットワーク基盤を反映
cd aws/stacks/network
terraform apply -var-file=../../environments/staging/terraform.tfvars

# staging 環境のアプリケーション層を反映
cd aws/stacks/application
terraform apply -var-file=../../environments/staging/terraform.tfvars
```

### Valkey 操作 (valkey-cli)
Redis と互換性がありますが、ツール名は `valkey-cli` を使用します。

```bash
# 接続
valkey-cli -h <endpoint> -p 6379

# 1. 分散ロック (アトミックなセットと期限設定)
SET my_lock "locked" NX EX 30

# 2. ランキング (Sorted Set)
ZADD game_ranking 100 "user1"
ZREVRANGE game_ranking 0 2 WITHSCORES

# 3. ユーザープロファイル (Hash)
HSET user:1001 name "Taro" age 25 email "taro@example.com"
HGET user:1001 email
```

### MySQL 操作と概念 (RDBMS)
```sql
-- 接続状況の確認
SHOW FULL PROCESSLIST;

-- 実行計画の確認
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';
```

---

## 4. 運用上の注意 (Git Management)

- **巨大ファイルの除外**: `.terraform/` ディレクトリは必ず `.gitignore` で除外する。
- **Stateの保護**: `*.tfstate` ファイルはリモートバックエンド（S3等）での管理を推奨。
