# Project Architecture & Knowledge Base

このドキュメントでは、本プロジェクトの Terraform 構成設計指針と、導入されている技術要素（Valkey等）に関する知見をまとめています。

## 1. Terraform 構成設計 (AWS)

### 階層構造と役割分離 (SoC)
サービスレイヤーを「基盤層 (Foundation)」と「アプリケーション層 (Application)」に分離し、ライフサイクルを独立させています。

- **`aws/services/common`**: 基盤層。VPC、サブネット、共通セキュリティグループなど、変更頻度が低く、プロジェクト全体で共有されるリソースを管理。
- **`aws/services/staging`**: アプリケーション層。EC2、ECS、ALB、分析基盤など、環境固有のリソースを管理。

### 依存性の注入 (Dependency Injection)
レイヤー間の結合を疎にするため、直接的なモジュール参照ではなく **AWS Data Sources** を利用した DI を採用しています。

- **手法**: `common` で作成したリソースに特定のタグ（例: `FoundationLayer = "true"`) を付与し、`staging` 側でそのタグを元に検索・取得。
- **メリット**: 基盤側のコード変更がアプリ側に即時波及するリスクを抑え、安全なリリースサイクルを実現。

### ファイル構成の標準化
各ディレクトリは以下の役割に基づいて 4 つのファイルに分割されています。

| ファイル名 | 役割 |
| :--- | :--- |
| `main.tf` | リソースの構成・組み立て (Blueprint) |
| `locals.tf` | 内部ロジック、タグ設定、固定値 (Internal Logic) |
| `variables.tf` | 外部からの入力、型定義 (Interface / Schema) |
| `outputs.tf` | 他の層への公開情報 (API / Public Interface) |

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

### Terraform 基本操作
各環境（`common`, `staging`）のディレクトリに移動して実行します。

```bash
# 初期化 (バイナリのダウンロード)
terraform init

# 実行計画の確認 (変更内容のレビュー)
terraform plan

# 反映
terraform apply

# 特定のリソースの状態を確認
terraform state show module.app.aws_instance.this[0]

# 基盤(common)のタグ情報を再スキャンしてDIを更新する場合
terraform plan -refresh-only
```

### Valkey 操作 (valkey-cli)
Redis と互換性がありますが、ツール名は `valkey-cli` を使用します。

```bash
# 接続
valkey-cli -h <endpoint> -p 6379

# 1. 分散ロック (アトミックなセットと期限設定)
# キーが存在しない(NX)場合のみ、30秒間(EX 30)セットする
SET my_lock "locked" NX EX 30

# 2. ランキング (Sorted Set)
# 2. ランキング (Sorted Set)
# ユーザー "user1" にスコア 100 を設定
ZADD game_ranking 100 "user1"
# 上位3名を取得 (降順)
ZREVRANGE game_ranking 0 2 WITHSCORES

# 3. ユーザープロファイル (Hash)
HSET user:1001 name "Taro" age 25 email "taro@example.com"
# 特定のフィールドを取得
HGET user:1001 email
# 全フィールドを取得
HGETALL user:1001

### データ取得とスキャン (運用・調査用)
大量のデータがある環境で `KEYS *` を使うと、シングルスレッドの Valkey/Redis ではサービスが停止する恐れがあるため、`SCAN` を使用します。

```bash
# 安全なキーの検索 (10件ずつカーソルを回して取得)
SCAN 0 MATCH user:* COUNT 10

# Hash内のフィールドを走査
HSCAN user:1001 0 MATCH e*
```

### クラスター環境での操作
Valkey Cluster では、データが 16384 個のハッシュスロットに分割して保存されています。

```bash
# クラスターモードで接続 (-c オプションが必須)
# これにより、キーの所在ノードが異なる場合に自動でリダイレクトされる
valkey-cli -c -h <cluster-endpoint> -p 6379

# どのノードにどのスロットが割り当てられているか確認
CLUSTER NODES

# 特定のキーがどのスロット・どのノードにあるか特定する
# 1. キーのスロット番号を算出
CLUSTER KEYSLOT "user:1001"
# 2. そのスロットを担当するノードを特定し、直接接続して取得する場合 (リダイレクトなし)
GET "user:1001"

# クラスター全体から特定のパターンに一致するキーを探す (工夫が必要)
# 各ノードに対して SCAN を個別に実行する必要があるため、スクリプト等で全ノードを回すのが一般的
```

---

## 4. 運用上の注意 (Git Management)

- **巨大ファイルの除外**: `.terraform/` ディレクトリには数・サイズ共に膨大なバイナリが含まれるため、必ず `.gitignore` で除外する。
- **Stateの保護**: `*.tfstate` ファイルには機密情報が含まれる可能性があるため、リモートバックエンド（S3等）の使用を推奨。
