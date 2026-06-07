# 運用調査ガイド (Athenaログ解析)

このドキュメントでは、Athena を使用してコスト効率よくログを調査する手順を説明します。

## コスト最適化の鉄則：パーティション指定
Athena はスキャンしたデータ量に対して課金されます。**必ず `year`, `month`, `day`, `hour` のパーティションを指定して検索してください。** これにより、スキャン対象を特定の時間枠に絞り込み、コストを 1/10,000 以下に抑えることができます。

### VPC Flow Logs の調査例

#### 1. 特定の1時間における拒否された通信の調査
```sql
SELECT srcaddr, dstaddr, dstport, protocol, bytes
FROM vpc_flow_logs
WHERE year = '2026' 
  AND month = '06' 
  AND day = '07' 
  AND hour = '10'  -- ★重要: パーティションを指定
  AND action = 'REJECT'
ORDER BY bytes DESC
LIMIT 100;
```

#### 2. 特定の内部IPからの異常な通信量の特定
```sql
SELECT srcaddr, SUM(bytes) / 1024 / 1024 as MB
FROM vpc_flow_logs
WHERE year = '2026' 
  AND month = '06' 
  AND day = '07'
  AND srcaddr LIKE '10.%'
GROUP BY srcaddr
ORDER BY MB DESC;
```

---

## 運用時の Tips
- **スキャン量制限:** Athena のワークグループ設定で「1クエリあたりの最大スキャン量（例: 10GB）」を設定しており、予期せぬ高額請求を防止しています。
- **Parquet形式:** ログは Parquet 形式で保存されているため、列指向（必要なカラムだけ読み込む）のスキャンが自動的に行われ、さらにコストが最適化されています。

### コンテナ (ECS) アプリケーションログの調査例

#### 1. 特定の時間帯の ERROR ログの抽出
```sql
SELECT timestamp, container_name, message, trace_id
FROM app_logs
WHERE year = '2026'
  AND month = '06'
  AND day = '07'
  AND hour = '15'
  AND log_level = 'ERROR'
ORDER BY timestamp DESC
LIMIT 100;
```

#### 2. 特定のトレースIDに関連する全ログの横断検索
```sql
SELECT timestamp, log_level, message
FROM app_logs
WHERE year = '2026'
  AND month = '06'
  AND trace_id = 'abc-123-def-456' -- 特定のリクエストを追跡
ORDER BY timestamp ASC;
```
