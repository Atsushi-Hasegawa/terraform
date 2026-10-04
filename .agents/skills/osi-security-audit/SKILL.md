---
name: osi-security-audit
description: Terraformコードに対するOSI参照モデル（L1〜L7）に基づくセキュリティ監査、自動修正（--fix/パッチ生成）、Conftest (OPA) ポリシー検査、および実行前遮断ゲート（pre_apply_gate.sh）の運用手順とガイドライン。インフラのセキュリティチェックやレビュー、ポリシー準拠の確認時に使用します。
---

# OSI 参照モデル セキュリティ監査 & ガバナンス運用スキル (OSI Security Audit)

このスキルは、Terraform で構成されたクラウドインフラに対して、**OSI 参照モデル（L1〜L7）に基づく多層防御チェック**、**具体的な修正コード提案・自動修復**、および **Conftest (OPA) によるデプロイ前遮断ゲート** を実行・運用するための専門ガイドラインです。

---

## 1. 監査観点と OSI 7階層の対応関係

| レイヤ | 分類 | 主な監査項目 | 対策・保護目的 |
| :--- | :--- | :--- | :--- |
| **L1** | 物理層 (Physical) | リージョン制限 (`ap-northeast-1`), Multi-AZ サブネット分散 | データ主権・データセンター物理障害耐性 |
| **L2** | データリンク層 (Data Link) | 専用 VPC 境界定義 | AWS Hypervisor による MAC/ARP スプーフィング遮断 |
| **L3** | ネットワーク層 (Network) | Public/Private サブネット分離, VPC Flow Logs, カスタム NACL | IP レベルの境界分離、通信フォレンジック、悪性パケット拒否 |
| **L4** | トランスポート層 (Transport) | 管理ポート(22/3389)非公開, DBポート保護(SGチェイニング), Egress最小権限化 | ポートスキャン防御、C2通信・データ持ち出し(Exfiltration)防止 |
| **L5** | セッション層 (Session) | ALB HTTPS 強制・301リダイレクト, TLS 1.2/1.3 暗号スイート強制 | 通信の盗聴防止、POODLE/BEAST 等の既知攻撃遮断 |
| **L6** | プレゼンテーション層 (Presentation) | RDS SSL強制 (`require_secure_transport=ON`), EBS/RDS/S3 CMK暗号化 | 伝送中・保存時データの暗号化 (Data-at-Rest/In-Transit) |
| **L7** | アプリケーション層 (Application) | AWS WAFv2 アタッチ, 不正ヘッダードロップ, IMDSv2 強制, コンテナ読み取り専用FS | SQLi/XSS防御、HTTPスマグリング防止、SSRF・ロール奪取防止 |

---

## 2. コアワークフロー

### ① 静的セキュリティ監査と修正案の確認
インフラコード全体に対して監査を実行し、問題箇所と具体的な推奨 HCL スニペットを出力します。

```bash
# 基本実行 (コンソール表示 + 推奨修正コード)
python3 scripts/osi_security_audit.py

# 差分 (Unified Diff) をターミナル上にプレビュー表示
python3 scripts/osi_security_audit.py --show-diff

# Markdown 形式でレポートを出力
python3 scripts/osi_security_audit.py --markdown -o docs/security_audit_report.md

# Mermaid トポロジー図のみを出力
python3 scripts/osi_security_audit.py --mermaid-only
```

### ② 自動修正 (`--fix`) またはパッチ生成 (`--generate-patch`)
検出された問題に対して、安全な修正を自動適用するかパッチとして書き出します。

```bash
# 変更内容を事前シミュレーション (Dry-run)
python3 scripts/osi_security_audit.py --fix --dry-run

# 安全に自動修正を適用 (.bak バックアップを自動作成)
python3 scripts/osi_security_audit.py --fix

# Unified Diff パッチファイルとして出力して後から適用
python3 scripts/osi_security_audit.py --generate-patch osi_remediation.patch
git apply osi_remediation.patch
```

### ③ デプロイ前セキュリティ遮断ゲート (`pre_apply_gate.sh`)
平文シークレット、OSI 監査、Conftest OPA ポリシー、Trivy スキャンの全基準を満たしているかを検証します。
**HIGH または CRITICAL の問題が存在する場合、Exit Code 1 で即座に実行をブロックします。**

```bash
# リポジトリ全体の静的検証
./scripts/pre_apply_gate.sh

# 特定の Terraform Plan JSON を渡して OPA 検証
./scripts/pre_apply_gate.sh path/to/tfplan.json
```

### ④ 安全な Terraform Apply (`tf_safe_apply.sh`)
Terraform のデプロイ時に、事前にゲートを自動通過した場合のみ `apply` を実行します。

```bash
./scripts/tf_safe_apply.sh aws/stacks/network
```

---

## 3. ルール設定と例外抑止のカスタマイズ ([`scripts/osi_rules.yaml`](../../scripts/osi_rules.yaml))

プロジェクト固有の要件に合わせてルールや重要度を調整できます。

```yaml
settings:
  fail_on_severity: ["CRITICAL", "HIGH"]
  allowed_regions: ["ap-northeast-1"]
  dangerous_ports: ["22", "3389"]

# 例外抑止 (Suppression)
suppressions:
  - check_id: "L3-NETWORK-ACL"
    resource: "aws_network_acl.external_fw"
    reason: "Managed by physical security appliance"

# 個別ルールの上書き
rules:
  L1-MULTI-AZ:
    enabled: true
    severity: LOW  # 検証環境向けに重要度を緩和
```

---

## 4. 回帰テストの実行

ツールのロジック変更や新ルール追加時は、必ず pytest を実行してテストを通過させてください。

```bash
pytest tests/test_osi_security_audit.py -v
```

---

## 5. Git Pre-Commit Hook の設定

新規環境でコミット時の自動遮断を有効にするには、以下のスクリプトを実行してフックを登録します：

```bash
./scripts/install_hooks.sh
```
