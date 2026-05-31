# Project Architecture & Knowledge Base

このドキュメントでは、本プロジェクトの Terraform 構成設計指針と、導入されている技術要素（Valkey等）に関する知見をまとめています。

## 1. Terraform 構成設計 (AWS)

### 階層構造と役割分離 (Environment & Stack)
大規模なインフラを安全に管理するため、設計図（Stacks）と実体（Environments）を分離しています。

- **`aws/modules/`**: 原子的な単一リソースの定義。
- **`aws/stacks/`**: 複数のモジュールを組み合わせた「機能単位の設計図」。依存関係（VPC ID等）は変数として受け取る DI 設計。
- **`aws/environments/`**: 各環境（staging, production 等）の具体的な定義。Stacks にパラメータを注入してリソースを実体化する。

| レイヤー | ディレクトリ | 主な役割 |
| :--- | :--- | :--- |
| Foundation | `environments/common` | VPC, 基盤セキュリティグループの作成 |
| Application | `environments/staging` | 基盤情報を DI で受け取り、アプリスタックを実体化 |

### 依存性の注入 (Dependency Injection)
レイヤー間およびスタック間の結合を疎にするため、Data Sources を利用した DI を採用しています。

- **`stacks` の設計**: `vpc_id` や `subnet_ids` をハードコードせず、必ず `variable` で受け取るように設計。
- **DI の流れ**: `environments` 側で Data Source を用いて既存リソースを検索し、その ID を `stacks` モジュールに注入する。


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

### MySQL 操作と概念 (RDBMS)
アプリケーションの永続データ管理に使用します。

#### 1. コア概念
- **ACID特性**: Atomicity（原子性）、Consistency（一貫性）、Isolation（独立性）、Durability（永続性）を保証。
- **インデックス (B-Tree)**: 高速な検索のために不可欠。ただし、過剰なインデックスは書き込み性能を低下させる。
- **デッドロック**: 複数のトランザクションが互いにロックを待ち続ける状態。発生時はMySQLが自動検知して一方をロールバックする。

#### 2. 運用・調査用クエリ

```sql
-- 1. 接続状況の確認 (誰が重い処理をしているか)
SHOW FULL PROCESSLIST;

-- 2. 実行計画の確認 (インデックスが効いているか)
-- 検索時に全件走査(type: ALL)になっていないかチェック
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';

-- 3. インデックスの確認
SHOW INDEX FROM users;

-- 4. トランザクションの基本操作
START TRANSACTION;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT; -- または ROLLBACK;

-- 5. 現在のロック状況を確認 (トラブルシューティング時)
SELECT * FROM information_schema.innodb_locks;
SELECT * FROM information_schema.innodb_trx;
```

#### 3. 運用のベストプラクティス
- **SELECT * を避ける**: 必要なカラムだけを取得することで、メモリ使用量とネットワーク転送量を削減する。
- **大規模な削除・更新は分割する**: 大量の行を一度に DELETE/UPDATE すると、長時間ロックがかかりサービス停止の原因になるため、LIMIT を使って小分けにする。
- **バックアップ**: Terraform (RDS等) のスナップショット機能を活用し、自動バックアップと復元（Point-in-Time Recovery）を常に有効にする。

---

## 4. 運用上の注意 (Git Management)

- **巨大ファイルの除外**: `.terraform/` ディレクトリには数・サイズ共に膨大なバイナリが含まれるため、必ず `.gitignore` で除外する。
- **Stateの保護**: `*.tfstate` ファイルには機密情報が含まれる可能性があるため、リモートバックエンド（S3等）の使用を推奨。
