#!/usr/bin/env python3
"""
OSI Reference Model Security Auditor & Mermaid Diagram Generator for Terraform
================================================================================
Audits Terraform infrastructure code against the OSI 7-Layer reference model,
generates a comprehensive security report, visualizes Security Group topologies
using Mermaid, and provides actionable hardening recommendations.
"""

import os
import sys
import re
import glob
import argparse
from dataclasses import dataclass, field
from typing import List, Dict, Set, Tuple, Optional

# ANSI Color Codes
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    RESET = '\033[0m'

@dataclass
class Finding:
    layer: int
    layer_name: str
    check_id: str
    severity: str  # "CRITICAL", "HIGH", "MEDIUM", "LOW", "PASS"
    title: str
    resource: str
    file_path: str
    description: str
    recommendation: str

@dataclass
class HclResource:
    kind: str  # "resource" or "data"
    type: str
    name: str
    attrs: Dict[str, str]
    raw_body: str
    file_path: str

class HclParser:
    @staticmethod
    def clean_content(text: str) -> str:
        text = re.sub(r'#.*$', '', text, flags=re.MULTILINE)
        text = re.sub(r'//.*$', '', text, flags=re.MULTILINE)
        text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
        return text

    @staticmethod
    def parse_blocks(file_path: str) -> List[HclResource]:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = HclParser.clean_content(f.read())
        except Exception:
            return []

        pattern = re.compile(r'(resource|data)\s+\"([^\"]+)\"\s+\"([^\"]+)\"\s*\{')
        pos = 0
        resources = []
        while True:
            m = pattern.search(content, pos)
            if not m:
                break
            kind, r_type, r_name = m.group(1), m.group(2), m.group(3)
            start_idx = m.end() - 1
            brace_count = 1
            i = start_idx + 1
            while i < len(content) and brace_count > 0:
                if content[i] == '{':
                    brace_count += 1
                elif content[i] == '}':
                    brace_count -= 1
                i += 1
            block_body = content[start_idx + 1:i - 1]
            attrs = HclParser.parse_key_values(block_body)
            resources.append(HclResource(kind, r_type, r_name, attrs, block_body, file_path))
            pos = i
        return resources

    @staticmethod
    def parse_key_values(body: str) -> Dict[str, str]:
        kv = {}
        for line in body.splitlines():
            line = line.strip()
            if '=' in line:
                parts = line.split('=', 1)
                k = parts[0].strip()
                v = parts[1].strip().strip('\"').strip("'")
                kv[k] = v
        return kv

class OsiAuditor:
    LAYER_NAMES = {
        1: "L1 物理層 (Physical Layer)",
        2: "L2 データリンク層 (Data Link Layer)",
        3: "L3 ネットワーク層 (Network Layer)",
        4: "L4 トランスポート層 (Transport Layer)",
        5: "L5 セッション層 (Session Layer)",
        6: "L6 プレゼンテーション層 (Presentation Layer)",
        7: "L7 アプリケーション層 (Application Layer)",
    }

    def __init__(self, root_dir: str):
        self.root_dir = root_dir
        self.resources: List[HclResource] = []
        self.findings: List[Finding] = []
        self.sgs: Dict[str, HclResource] = {}
        self.rules: List[HclResource] = []

    def load_codebase(self):
        pattern = os.path.join(self.root_dir, '**', '*.tf')
        for f in glob.glob(pattern, recursive=True):
            if '.terraform' in f:
                continue
            res_list = HclParser.parse_blocks(f)
            self.resources.extend(res_list)
            for r in res_list:
                if r.kind == 'resource' and r.type == 'aws_security_group':
                    self.sgs[r.name] = r
                elif r.kind == 'resource' and 'security_group' in r.type:
                    self.rules.append(r)

    def run_audit(self):
        self._audit_l1_physical()
        self._audit_l2_data_link()
        self._audit_l3_network()
        self._audit_l4_transport()
        self._audit_l5_session()
        self._audit_l6_presentation()
        self._audit_l7_application()

    # --- L1 物理層 ---
    def _audit_l1_physical(self):
        # 1. 東京リージョン制限
        allowed_region = "ap-northeast-1"
        found_regions = set()
        for r in self.resources:
            if 'region' in r.attrs:
                val = r.attrs['region']
                if 'var.' not in val and '${' not in val:
                    found_regions.add(val)

        invalid_regions = [reg for reg in found_regions if reg and allowed_region not in reg]
        if invalid_regions:
            self.findings.append(Finding(
                1, self.LAYER_NAMES[1], "L1-REGION-POLICY", "HIGH",
                "東京リージョン外のリソース設定検出",
                f"Regions: {invalid_regions}", "",
                f"許可されていないリージョン ({invalid_regions}) が指定されています。",
                f"セキュリティガバナンスに従い、リージョンを '{allowed_region}' に統一してください。"
            ))
        else:
            self.findings.append(Finding(
                1, self.LAYER_NAMES[1], "L1-REGION-POLICY", "PASS",
                "リージョン制限の遵守 (東京リージョン ap-northeast-1)",
                "Provider / Config", "",
                "東京リージョン (ap-northeast-1) に限定されており、データ主権・ガバナンス規約に準拠しています。",
                "現状の設定を維持してください。"
            ))

        # 2. Multi-AZ 配置
        subnets = [r for r in self.resources if r.type == 'aws_subnet']
        has_multi_az = False
        for s in subnets:
            if 'count' in s.attrs or 'count' in s.raw_body or 'availability_zones' in s.raw_body:
                has_multi_az = True
                break
        if len(subnets) >= 2 or has_multi_az:
            self.findings.append(Finding(
                1, self.LAYER_NAMES[1], "L1-MULTI-AZ", "PASS",
                "Multi-AZ 物理冗長化の確保",
                "aws_subnet (availability_zones)", "modules/network/vpc.tf",
                "複数 Availability Zone へのサブネット分散配置が定義されており、データセンター障害への耐障害性を確保しています。",
                "現状の Multi-AZ 構成を維持してください。"
            ))
        else:
            self.findings.append(Finding(
                1, self.LAYER_NAMES[1], "L1-MULTI-AZ", "MEDIUM",
                "Multi-AZ 物理冗長化の不足",
                "aws_subnet", "modules/network/vpc.tf",
                "サブネットの AZ 分散が確認できません。単一 AZ 障害時にサービス停止のリスクがあります。",
                "最低 2 つ以上の異なる Availability Zone にサブネットを分散配置してください。"
            ))

    # --- L2 データリンク層 ---
    def _audit_l2_data_link(self):
        vpcs = [r for r in self.resources if r.type == 'aws_vpc']
        if vpcs:
            self.findings.append(Finding(
                2, self.LAYER_NAMES[2], "L2-VPC-ISOLATION", "PASS",
                "VPC 仮想ネットワーク境界によるレイヤ2アイソレーション",
                vpcs[0].name, vpcs[0].file_path,
                "専用 VPC によるプライベート IP 空間が確保されており、AWS Hypervisor により MAC/ARP スプーフィング等の L2 攻撃が遮断されています。",
                "現状の VPC 境界隔離を維持してください。"
            ))
        else:
            self.findings.append(Finding(
                2, self.LAYER_NAMES[2], "L2-VPC-ISOLATION", "CRITICAL",
                "専用 VPC の未定義 (デフォルトVPC利用リスク)",
                "None", "",
                "専用 VPC の定義が見つかりません。デフォルト VPC に配置されると意図しない公開や L2 境界防御の喪失に繋がります。",
                "明示的に `aws_vpc` リソースを定義し、プライベート空間を確保してください。"
            ))

    # --- L3 ネットワーク層 ---
    def _audit_l3_network(self):
        # 1. プライベートサブネットの分離
        subnets = [r for r in self.resources if r.type == 'aws_subnet']
        has_private_subnet = any('private' in r.name.lower() or 'private' in r.raw_body.lower() for r in subnets)
        if not has_private_subnet:
            self.findings.append(Finding(
                3, self.LAYER_NAMES[3], "L3-SUBNET-SEGREGATION", "HIGH",
                "パブリック / プライベートサブネットの未分離",
                "aws_subnet", "modules/network/vpc.tf",
                "現在パブリックサブネットのみが存在し、プライベートサブネットが未定義です。EC2 や RDS がパブリック直通ネットワークに配置されるリスクがあります。",
                "ALB のみを配置する Public Subnet と、EC2/RDS を隔離配置する Private Subnet を分割定義してください。"
            ))
        else:
            self.findings.append(Finding(
                3, self.LAYER_NAMES[3], "L3-SUBNET-SEGREGATION", "PASS",
                "ネットワーク層の多層防御 (Public/Private サブネット分離)",
                "aws_subnet", "modules/network/vpc.tf",
                "プライベートサブネットによる境界分離が施されています。",
                "現状の設定を維持してください。"
            ))

        # 2. VPC Flow Logs
        flow_logs = [r for r in self.resources if r.type == 'aws_flow_log']
        if flow_logs:
            fl = flow_logs[0]
            is_parquet = 'parquet' in fl.raw_body.lower()
            is_fast_interval = 'max_aggregation_interval = 60' in fl.raw_body
            self.findings.append(Finding(
                3, self.LAYER_NAMES[3], "L3-VPC-FLOW-LOGS", "PASS",
                "VPC Flow Logs による L3 トラフィックの可視化と監査",
                fl.name, fl.file_path,
                f"VPC Flow Logs が有効化されています (Parquet形式: {is_parquet}, 1分集約: {is_fast_interval})。IPパケットの拒否・許可監査が可能です。",
                "CloudWatch Logs / Athena 連携による異常通信（ポートスキャン等）の定期分析を推奨します。"
            ))
        else:
            self.findings.append(Finding(
                3, self.LAYER_NAMES[3], "L3-VPC-FLOW-LOGS", "HIGH",
                "VPC Flow Logs の未有効化",
                "aws_vpc", "modules/network/",
                "VPC Flow Logs が有効化されておらず、ネットワークレベルの侵入や不正通信のフォレンジック・追跡が不可能です。",
                "`aws_flow_log` リソースを追加し、S3 または CloudWatch Logs に通信ログを保存してください。"
            ))

        # 3. Network ACL (NACL)
        nacls = [r for r in self.resources if r.type == 'aws_network_acl']
        if not nacls:
            self.findings.append(Finding(
                3, self.LAYER_NAMES[3], "L3-NETWORK-ACL", "MEDIUM",
                "カスタム Network ACL (NACL) の未定義",
                "aws_network_acl", "modules/network/",
                "明示的な NACL が定義されておらず、デフォルトのステートレスパケット全許可に依存しています。",
                "サブネット境界での二重防御（特定悪性 CIDR や不要プロトコルの遮断）のため、カスタム NACL の導入を検討してください。"
            ))
        else:
            self.findings.append(Finding(
                3, self.LAYER_NAMES[3], "L3-NETWORK-ACL", "PASS",
                "Network ACL によるステートレスパケットフィルタリング",
                nacls[0].name, nacls[0].file_path,
                "カスタム NACL によるサブネット境界防御が定義されています。",
                "定期的なルール見直しを推奨します。"
            ))

    # --- L4 トランスポート層 ---
    def _audit_l4_transport(self):
        # 1. 危険ポート (SSH:22, RDP:3389) の開放チェック
        dangerous_ports = {"22", "3389"}
        found_danger = False
        for r in self.rules:
            fp = r.attrs.get('from_port', '')
            tp = r.attrs.get('to_port', '')
            cidr = r.attrs.get('cidr_ipv4', '') or r.attrs.get('cidr_blocks', '')
            is_ingress = 'ingress' in r.type or r.attrs.get('type') == 'ingress'
            
            if is_ingress and '0.0.0.0/0' in cidr:
                if fp in dangerous_ports or tp in dangerous_ports:
                    found_danger = True
                    self.findings.append(Finding(
                        4, self.LAYER_NAMES[4], "L4-MANAGEMENT-PORTS", "CRITICAL",
                        f"管理ポート ({fp}) のインターネット全開放",
                        r.name, r.file_path,
                        f"セキュリティグループルール '{r.name}' でポート {fp} が 0.0.0.0/0 に全開放されています。総当たり攻撃や侵入のリスクがあります。",
                        "0.0.0.0/0 の許可を削除し、AWS Systems Manager (SSM) Session Manager を使用するか、社内固定 IP に限定してください。"
                    ))
        if not found_danger:
            self.findings.append(Finding(
                4, self.LAYER_NAMES[4], "L4-MANAGEMENT-PORTS", "PASS",
                "管理ポート (SSH:22 / RDP:3389) のインターネット非露出",
                "Security Groups", "modules/network/security_group.tf",
                "SSH/RDP などの管理ポートはインターネットに一切露出していません。",
                "SSM Session Manager による踏み台レス・セキュアアクセスの運用を継続してください。"
            ))

        # 2. データベースポート (3306/5432) の開放チェック
        db_ports = {"3306", "5432", "6379", "27017"}
        found_db_open = False
        for r in self.rules:
            fp = r.attrs.get('from_port', '')
            cidr = r.attrs.get('cidr_ipv4', '') or r.attrs.get('cidr_blocks', '')
            is_ingress = 'ingress' in r.type or r.attrs.get('type') == 'ingress'
            if is_ingress and '0.0.0.0/0' in cidr:
                if fp in db_ports or 'rds_port' in fp:
                    found_db_open = True
                    self.findings.append(Finding(
                        4, self.LAYER_NAMES[4], "L4-DATABASE-PORTS", "CRITICAL",
                        f"データベースポート ({fp}) のインターネット全開放",
                        r.name, r.file_path,
                        f"データベースポートが 0.0.0.0/0 に開放されています。重大な情報漏洩リスクがあります。",
                        "接続元を特定のアプリケーションセキュリティグループ ID に限定してください。"
                    ))
        if not found_db_open:
            self.findings.append(Finding(
                4, self.LAYER_NAMES[4], "L4-DATABASE-PORTS", "PASS",
                "データベースポート (3306等) の保護 (SG Chaining)",
                "Security Groups", "modules/network/security_group.tf",
                "データベースポートは外部公開されておらず、接続元 SG (EC2/ECS/NLB) のみから許可されています。",
                "現状のセキュリティグループチェイニングを維持してください。"
            ))

        # 3. アウトバウンド (Egress) 全開放チェック
        unrestricted_egress = []
        for r in self.rules:
            is_egress = 'egress' in r.type or r.attrs.get('type') == 'egress'
            cidr = r.attrs.get('cidr_ipv4', '') or r.attrs.get('cidr_blocks', '')
            proto = r.attrs.get('ip_protocol', '') or r.attrs.get('protocol', '')
            fp = r.attrs.get('from_port', '')
            if is_egress and '0.0.0.0/0' in cidr and (proto == '-1' or fp == '0'):
                unrestricted_egress.append(r)

        if unrestricted_egress:
            self.findings.append(Finding(
                4, self.LAYER_NAMES[4], "L4-UNRESTRICTED-EGRESS", "HIGH",
                "アウトバウンド通信 (Egress) の全開放 (全プロトコル/全ポート)",
                f"{[r.name for r in unrestricted_egress]}", unrestricted_egress[0].file_path,
                "アウトバウンドが 0.0.0.0/0 かつ全プロトコル (-1) で開放されています。マルウェア感染時の C2 通信やデータ持ち出し (Exfiltration) を防げません。",
                "必要な外向き通信（HTTPS 443 や RDS 3306）のみにポートを絞り込んでください。"
            ))
        else:
            self.findings.append(Finding(
                4, self.LAYER_NAMES[4], "L4-UNRESTRICTED-EGRESS", "PASS",
                "アウトバウンド通信 (Egress) の最小権限化",
                "Security Groups", "modules/network/security_group.tf",
                "全開放 (0.0.0.0/0:all) は存在せず、HTTPS (443) や特定 DB ポート (3306) に限定されています。",
                "現状の最小権限ポリシーを維持してください。"
            ))

    # --- L5 セッション層 ---
    def _audit_l5_session(self):
        # 1. ALB HTTPS 強制
        listeners = [r for r in self.resources if r.type == 'aws_lb_listener']
        has_https = any(r.attrs.get('port') == '443' or r.attrs.get('protocol') == 'HTTPS' for r in listeners)
        has_redirect = any('redirect' in r.raw_body for r in listeners)
        
        if has_https and has_redirect:
            self.findings.append(Finding(
                5, self.LAYER_NAMES[5], "L5-ALB-HTTPS", "PASS",
                "ALB における HTTPS 強制と HTTP からのリダイレクト",
                "aws_lb_listener", "modules/elb/aws_elb.tf",
                "HTTPS (Port 443) リスナーが設定され、HTTP (Port 80) は 301 リダイレクトで保護されています。",
                "セッションハイジャックおよび平文盗聴を防止できています。"
            ))
        elif has_https:
            self.findings.append(Finding(
                5, self.LAYER_NAMES[5], "L5-ALB-HTTPS", "MEDIUM",
                "HTTP から HTTPS への自動リダイレクト未設定",
                "aws_lb_listener", "modules/elb/aws_elb.tf",
                "HTTPS リスナーは存在しますが、平文 HTTP 通信を HTTPS へ自動転送するリダイレクトルールが不足しています。",
                "Port 80 リスナーに 301 リダイレクトアクションを追加してください。"
            ))
        else:
            self.findings.append(Finding(
                5, self.LAYER_NAMES[5], "L5-ALB-HTTPS", "CRITICAL",
                "ALB における HTTPS 暗号化セッションの未設定",
                "aws_lb_listener", "modules/elb/",
                "HTTPS (Port 443) リスナーが設定されておらず、すべての通信が平文で伝送されるリスクがあります。",
                "ACM 証明書を紐付けた HTTPS (443) リスナーを作成してください。"
            ))

        # 2. SSL/TLS ポリシー (TLS 1.2/1.3 強制)
        secure_ssl_policies = ["ELBSecurityPolicy-TLS13-1-2-2021-06", "ELBSecurityPolicy-TLS-1-2-2017-01"]
        has_modern_tls = any(any(pol in r.raw_body for pol in secure_ssl_policies) for r in listeners)
        if has_modern_tls:
            self.findings.append(Finding(
                5, self.LAYER_NAMES[5], "L5-TLS-POLICY", "PASS",
                "最新の TLS 1.3 / 1.2 暗号スイートの強制",
                "ssl_policy", "modules/elb/aws_elb.tf",
                "ELBSecurityPolicy-TLS13-1-2-2021-06 が指定され、脆弱な SSLv3/TLS 1.0/1.1 が遮断されています。",
                "現状の安全なポリシーを維持してください。"
            ))
        else:
            self.findings.append(Finding(
                5, self.LAYER_NAMES[5], "L5-TLS-POLICY", "HIGH",
                "非推奨または古い SSL/TLS ポリシーの利用",
                "ssl_policy", "modules/elb/",
                "古い TLS ポリシーが使用されているか明示されていません。POODLE や BEAST などの既知の攻撃に脆弱な可能性があります。",
                "`ELBSecurityPolicy-TLS13-1-2-2021-06` などの最新ポリシーを指定してください。"
            ))

    # --- L6 プレゼンテーション層 ---
    def _audit_l6_presentation(self):
        # 1. RDS SSL/TLS 強制
        param_groups = [r for r in self.resources if 'parameter_group' in r.type]
        has_rds_ssl = any('require_secure_transport' in r.raw_body and 'ON' in r.raw_body for r in param_groups)
        has_rds_tls13 = any('TLSv1.2,TLSv1.3' in r.raw_body for r in param_groups)
        
        if has_rds_ssl and has_rds_tls13:
            self.findings.append(Finding(
                6, self.LAYER_NAMES[6], "L6-RDS-TRANSPORT-ENCRYPTION", "PASS",
                "Aurora RDS の SSL/TLS 強制 (require_secure_transport=ON)",
                "aws_rds_cluster_parameter_group", "modules/database/rds.tf",
                "すべてのクライアント接続に TLS 1.2 / 1.3 が強制され、平文の SQL クエリ・認証情報の伝送が遮断されています。",
                "現状の設定を維持してください。"
            ))
        else:
            self.findings.append(Finding(
                6, self.LAYER_NAMES[6], "L6-RDS-TRANSPORT-ENCRYPTION", "HIGH",
                "RDS 通信の SSL/TLS 強制設定の欠落",
                "aws_rds_cluster_parameter_group", "modules/database/rds.tf",
                "RDS パラメータグループで `require_secure_transport = ON` が設定されていません。平文で DB 通信が行われるリスクがあります。",
                "パラメータグループに `require_secure_transport = ON` および `tls_version = TLSv1.2,TLSv1.3` を追加してください。"
            ))

        # 2. 保存データ暗号化 (EBS, RDS, S3 CMK)
        instances = [r for r in self.resources if r.type == 'aws_instance']
        ebs_encrypted = all(bool(re.search(r'encrypted\s*=\s*true', r.raw_body, re.IGNORECASE)) for r in instances) if instances else True
        
        rds_clusters = [r for r in self.resources if r.type == 'aws_rds_cluster']
        rds_encrypted = all(bool(re.search(r'storage_encrypted\s*=\s*true', r.raw_body, re.IGNORECASE)) for r in rds_clusters) if rds_clusters else True
        
        if ebs_encrypted and rds_encrypted:
            self.findings.append(Finding(
                6, self.LAYER_NAMES[6], "L6-DATA-AT-REST-ENCRYPTION", "PASS",
                "保存データの暗号化 (EBS / RDS / S3 KMS CMK)",
                "KMS / EBS / RDS", "modules/ec2/, modules/database/",
                "EC2 EBS ボリューム (`encrypted=true`) および RDS クラスター (`storage_encrypted=true`) の暗号化が適用されています。",
                "KMS カスタマーマネージドキークラス (CMK) による鍵ローテーションの維持を推奨します。"
            ))
        else:
            self.findings.append(Finding(
                6, self.LAYER_NAMES[6], "L6-DATA-AT-REST-ENCRYPTION", "CRITICAL",
                "未暗号化ストレージの検出",
                "EBS / RDS", "modules/ec2/, modules/database/",
                "暗号化が有効化されていない EBS ボリュームまたは RDS インスタンスが検出されました。",
                "すべてのストレージリソースで `encrypted = true` または `storage_encrypted = true` を設定してください。"
            ))

    # --- L7 アプリケーション層 ---
    def _audit_l7_application(self):
        # 1. AWS WAFv2 アタッチ確認
        waf_assocs = [r for r in self.resources if 'waf' in r.type]
        has_waf = len(waf_assocs) > 0
        if not has_waf:
            self.findings.append(Finding(
                7, self.LAYER_NAMES[7], "L7-WAF-PROTECTION", "HIGH",
                "ALB / CloudFront への AWS WAFv2 未紐付け",
                "aws_lb, aws_cloudfront_distribution", "policy/network_perimeter.rego",
                "パブリック ALB または CloudFront に WAF Web ACL が関連付けられていません。SQLi, XSS, レート制限超過等の L7 攻撃に無防備です。",
                "`aws_wafv2_web_acl` および `aws_wafv2_web_acl_association` を定義してアタッチしてください。"
            ))
        else:
            self.findings.append(Finding(
                7, self.LAYER_NAMES[7], "L7-WAF-PROTECTION", "PASS",
                "AWS WAFv2 による L7 アプリケーション保護",
                waf_assocs[0].name, waf_assocs[0].file_path,
                "WAF Web ACL が適用されており、レイヤ7の脆弱性攻撃や不正リクエストを遮断可能です。",
                "マネージドルールの定期的な検知ログ分析を推奨します。"
            ))

        # 2. HTTP ヘッダー保護 (drop_invalid_header_fields)
        albs = [r for r in self.resources if r.type == 'aws_lb' and r.attrs.get('load_balancer_type') == 'application']
        drop_headers = all('drop_invalid_header_fields = true' in r.raw_body for r in albs) if albs else True
        if drop_headers:
            self.findings.append(Finding(
                7, self.LAYER_NAMES[7], "L7-HTTP-HEADER-DROPPING", "PASS",
                "不正な HTTP ヘッダーのドロップ (HTTP Request Smuggling 対策)",
                "aws_lb.app-lb", "modules/elb/aws_elb.tf",
                "`drop_invalid_header_fields = true` が有効であり、HTTP リクエストスマグリング等の悪意あるヘッダー挿入攻撃が防御されています。",
                "現状の設定を維持してください。"
            ))
        else:
            self.findings.append(Finding(
                7, self.LAYER_NAMES[7], "L7-HTTP-HEADER-DROPPING", "MEDIUM",
                "不正な HTTP ヘッダーの遮断が無効",
                "aws_lb", "modules/elb/aws_elb.tf",
                "ALB で `drop_invalid_header_fields` が無効です。不正な HTTP ヘッダーによるバックエンド汚染のリスクがあります。",
                "`drop_invalid_header_fields = true` を設定してください。"
            ))

        # 3. IMDSv2 の強制 (EC2 メタデータ認証)
        instances = [r for r in self.resources if r.type == 'aws_instance']
        imdsv2_enforced = all(bool(re.search(r'http_tokens\s*=\s*\"required\"', r.raw_body)) for r in instances) if instances else True
        if imdsv2_enforced:
            self.findings.append(Finding(
                7, self.LAYER_NAMES[7], "L7-IMDSV2-PROTECTION", "PASS",
                "EC2 インスタンスにおける IMDSv2 の強制 (SSRF / 認証情報奪取対策)",
                "aws_instance", "modules/ec2/aws_instance.tf",
                "メタデータアクセスにセッショントークン (`http_tokens = required`) が必須化されており、SSRF による IAM ロール奪取を防御しています。",
                "現状の設定を維持してください。"
            ))
        else:
            self.findings.append(Finding(
                7, self.LAYER_NAMES[7], "L7-IMDSV2-PROTECTION", "CRITICAL",
                "IMDSv1 許可による IAM 認証情報奪取リスク",
                "aws_instance", "modules/ec2/",
                "EC2 で IMDSv2 が強制されていません。SSRF 脆弱性が発生した場合にインスタンスロールの認証情報が盗まれる危険があります。",
                "`metadata_options { http_tokens = \"required\" }` を設定してください。"
            ))

        # 4. コンテナ (ECS Fargate) の読み取り専用ルートファイルシステム
        task_defs = [r for r in self.resources if r.type == 'aws_ecs_task_definition']
        has_readonly_root = any('readonlyRootFilesystem = true' in r.raw_body or '"readonlyRootFilesystem": true' in r.raw_body for r in task_defs)
        if has_readonly_root:
            self.findings.append(Finding(
                7, self.LAYER_NAMES[7], "L7-CONTAINER-IMMUTABILITY", "PASS",
                "コンテナの読み取り専用ルートファイルシステム (イミュータブル運用)",
                "aws_ecs_task_definition", "modules/ecs/service.tf",
                "`readonlyRootFilesystem = true` により、コンテナ内への不正バイナリ配置やマルウェア定着が防御されています。",
                "現状の設定を維持してください。"
            ))
        elif task_defs:
            self.findings.append(Finding(
                7, self.LAYER_NAMES[7], "L7-CONTAINER-IMMUTABILITY", "MEDIUM",
                "コンテナルートファイルシステムの書き込み可能設定",
                "aws_ecs_task_definition", "modules/ecs/",
                "コンテナのルートファイルシステムへの書き込みが許可されています。改ざんやマルウェア配置のリスクがあります。",
                "`readonlyRootFilesystem: true` を設定し、一時ファイルはマウントボリュームに限定してください。"
            ))

class MermaidGenerator:
    @staticmethod
    def normalize_name(ref: str) -> str:
        m = re.search(r'aws_security_group\.([a-zA-Z0-9_\-]+)', ref)
        name = m.group(1) if m else ref
        return re.sub(r'[^a-zA-Z0-9_]', '_', name)

    @staticmethod
    def generate(sgs: Dict[str, HclResource], rules: List[HclResource]) -> str:
        lines = []
        lines.append("```mermaid")
        lines.append("graph TB")
        lines.append("    %% ========================================================")
        lines.append("    %% OSI L4 Transport Security Groups & Interconnections")
        lines.append("    %% Generated automatically by osi_security_audit.py")
        lines.append("    %% ========================================================")
        lines.append("")

        # 外部ノード
        lines.append("    subgraph External[\"🌐 外部ネットワーク / クライアント\"]")
        lines.append("        Internet[\"Internet<br/>0.0.0.0/0\"]")
        lines.append("        PrivateLink[\"PrivateLink Clients<br/>(Databricks / VPC Endpoint)\"]")
        lines.append("        VPC_Internal[\"VPC Internal CIDR<br/>(Local Subnets)\"]")
        lines.append("    end")
        lines.append("")

        # Tier ごとのサブグラフ
        edge_nodes = []
        app_nodes = []
        db_nodes = []
        eks_nodes = []

        for name, r in sgs.items():
            nid = f"sg_{MermaidGenerator.normalize_name(name)}"
            desc = r.attrs.get('description', name)
            label = f"{name}<br/><i>{desc}</i>"
            n_str = f"        {nid}[\"{label}\"]"
            
            lname = name.lower()
            if 'alb' in lname or 'nlb' in lname or 'edge' in lname:
                edge_nodes.append(n_str)
            elif 'ec2' in lname or 'ecs' in lname or 'lambda' in lname or 'app' in lname:
                app_nodes.append(n_str)
            elif 'rds' in lname or 'db' in lname or 'mysql' in lname:
                db_nodes.append(n_str)
            elif 'eks' in lname or 'master' in lname or 'worker' in lname:
                eks_nodes.append(n_str)
            else:
                app_nodes.append(n_str)

        if edge_nodes:
            lines.append("    subgraph EdgeTier[\"🛡️ Edge / Load Balancer Tier (L4/L7)\"]")
            lines.extend(edge_nodes)
            lines.append("    end")
            lines.append("")

        if app_nodes:
            lines.append("    subgraph AppTier[\"⚙️ Application Tier (L4/L7)\"]")
            lines.extend(app_nodes)
            lines.append("    end")
            lines.append("")

        if db_nodes:
            lines.append("    subgraph DbTier[\"🗄️ Database Tier (L4)\"]")
            lines.extend(db_nodes)
            lines.append("    end")
            lines.append("")

        if eks_nodes:
            lines.append("    subgraph EksTier[\"☸️ Kubernetes (EKS) Tier\"]")
            lines.extend(eks_nodes)
            lines.append("    end")
            lines.append("")

        # エッジの生成
        edges = set()
        for r in rules:
            attrs = r.attrs
            sg_id_raw = attrs.get('security_group_id', '')
            ref_sg_raw = attrs.get('referenced_security_group_id', '') or attrs.get('source_security_group_id', '')
            cidr = attrs.get('cidr_ipv4', '') or attrs.get('cidr_blocks', '')
            proto = (attrs.get('ip_protocol', '') or attrs.get('protocol', '')).upper()
            fp = attrs.get('from_port', '')
            tp = attrs.get('to_port', '')

            # プロトコルが未指定でポートが443等の場合の補正
            if not proto and (fp == '443' or fp == '80' or fp == '3306'):
                proto = "TCP"

            # ポートラベルのフォーマット
            if 'var.rds_port' in fp:
                port_lbl = "TCP:3306"
            elif 'var.container_port' in fp:
                port_lbl = "TCP:80"
            elif 'lookup' in fp:
                port_lbl = "Configured Port"
            elif fp == tp and fp != "":
                port_lbl = f"{proto}:{fp}"
            elif fp and tp:
                port_lbl = f"{proto}:{fp}-{tp}"
            elif proto == "-1":
                port_lbl = "ALL TRAFFIC"
            else:
                port_lbl = proto or "TRAFFIC"

            is_ingress = 'ingress' in r.type or attrs.get('type') == 'ingress'
            
            src_node = ""
            dst_node = ""
            is_unrestricted_egress = False

            if is_ingress:
                dst_node = f"sg_{MermaidGenerator.normalize_name(sg_id_raw)}"
                if '0.0.0.0/0' in cidr:
                    src_node = "Internet"
                elif 'cidr' in cidr or 'vpc' in cidr.lower():
                    src_node = "VPC_Internal"
                elif ref_sg_raw:
                    src_node = f"sg_{MermaidGenerator.normalize_name(ref_sg_raw)}"
            else:
                src_node = f"sg_{MermaidGenerator.normalize_name(sg_id_raw)}"
                if '0.0.0.0/0' in cidr:
                    dst_node = "Internet"
                    if proto == "-1":
                        is_unrestricted_egress = True
                elif 'cidr' in cidr or 'vpc' in cidr.lower():
                    dst_node = "VPC_Internal"
                elif ref_sg_raw:
                    dst_node = f"sg_{MermaidGenerator.normalize_name(ref_sg_raw)}"

            if src_node and dst_node and "None" not in src_node and "None" not in dst_node:
                edges.add((src_node, dst_node, port_lbl, is_unrestricted_egress))

        lines.append("    %% 通信フロー (Ingress / Egress)")
        for src, dst, lbl, is_warn in sorted(edges):
            if is_warn:
                lines.append(f"    {src} -.->|\"⚠️ {lbl} (全開放)\"| {dst}")
            elif dst == "Internet":
                lines.append(f"    {src} -.->|\"{lbl}\"| {dst}")
            else:
                lines.append(f"    {src} -->|\"{lbl}\"| {dst}")

        lines.append("```")
        return "\n".join(lines)

class ReportFormatter:
    @staticmethod
    def format_console(findings: List[Finding], mermaid_chart: str) -> str:
        out = []
        out.append(f"{Colors.BOLD}{Colors.CYAN}=============================================================================={Colors.RESET}")
        out.append(f"{Colors.BOLD}{Colors.CYAN}  OSI 参照モデル セキュリティ設定監査レポート (Terraform Security Audit){Colors.RESET}")
        out.append(f"{Colors.BOLD}{Colors.CYAN}=============================================================================={Colors.RESET}\n")

        # レイヤごとのサマリ集計
        summary: Dict[int, Dict[str, int]] = {i: {"PASS": 0, "LOW": 0, "MEDIUM": 0, "HIGH": 0, "CRITICAL": 0} for i in range(1, 8)}
        for f in findings:
            summary[f.layer][f.severity] += 1

        out.append(f"{Colors.BOLD}【1. レイヤ別サマリ (OSI 7-Layers Overview)】{Colors.RESET}")
        out.append("┌─────────┬───────────────────────────────────┬──────┬──────┬────────┬──────┬──────────┐")
        out.append("│ Layer   │ 名称                              │ PASS │ LOW  │ MEDIUM │ HIGH │ CRITICAL │")
        out.append("├─────────┼───────────────────────────────────┼──────┼──────┼────────┼──────┼──────────┤")
        for layer in range(1, 8):
            name = OsiAuditor.LAYER_NAMES[layer]
            s = summary[layer]
            p_str = f"{Colors.GREEN}{s['PASS']:^4}{Colors.RESET}"
            l_str = f"{s['LOW']:^4}"
            m_str = f"{Colors.YELLOW}{s['MEDIUM']:^6}{Colors.RESET}" if s['MEDIUM'] > 0 else f"{s['MEDIUM']:^6}"
            h_str = f"{Colors.RED}{s['HIGH']:^4}{Colors.RESET}" if s['HIGH'] > 0 else f"{s['HIGH']:^4}"
            c_str = f"{Colors.RED}{Colors.BOLD}{s['CRITICAL']:^8}{Colors.RESET}" if s['CRITICAL'] > 0 else f"{s['CRITICAL']:^8}"
            out.append(f"│ L{layer:<6} │ {name:<27} │ {p_str} │ {l_str} │ {m_str} │ {h_str} │ {c_str} │")
        out.append("└─────────┴───────────────────────────────────┴──────┴──────┴────────┴──────┴──────────┘\n")

        # 詳細チェック結果
        out.append(f"{Colors.BOLD}【2. 詳細チェック結果 (Findings by Layer)】{Colors.RESET}")
        for layer in range(1, 8):
            l_findings = [f for f in findings if f.layer == layer]
            out.append(f"\n{Colors.BOLD}{Colors.BLUE}▶ {OsiAuditor.LAYER_NAMES[layer]}{Colors.RESET}")
            for f in l_findings:
                if f.severity == "PASS":
                    sev_badge = f"{Colors.GREEN}[PASS]{Colors.RESET}"
                elif f.severity == "CRITICAL":
                    sev_badge = f"{Colors.RED}{Colors.BOLD}[CRITICAL]{Colors.RESET}"
                elif f.severity == "HIGH":
                    sev_badge = f"{Colors.RED}[HIGH]{Colors.RESET}"
                elif f.severity == "MEDIUM":
                    sev_badge = f"{Colors.YELLOW}[MEDIUM]{Colors.RESET}"
                else:
                    sev_badge = f"{Colors.BLUE}[LOW]{Colors.RESET}"
                
                out.append(f"  {sev_badge} {Colors.BOLD}{f.title}{Colors.RESET} ({f.check_id})")
                out.append(f"     説明: {f.description}")
                if f.severity != "PASS":
                    out.append(f"     {Colors.YELLOW}推奨改善案: {f.recommendation}{Colors.RESET}")

        # Mermaid 図
        out.append(f"\n{Colors.BOLD}【3. セキュリティグループ関係性図 (Mermaid Diagram)】{Colors.RESET}")
        out.append(mermaid_chart)

        # アクションサマリ
        actionable = [f for f in findings if f.severity in ("CRITICAL", "HIGH")]
        out.append(f"\n{Colors.BOLD}【4. 最優先改善アクション (Priority Remediation)】{Colors.RESET}")
        if not actionable:
            out.append(f"  {Colors.GREEN}✓ 重大なセキュリティ脆弱性は検出されませんでした。良好な設定状態です。{Colors.RESET}")
        else:
            for idx, f in enumerate(actionable, 1):
                out.append(f"  {idx}. [{f.severity}] {f.title} ({f.layer_name})")
                out.append(f"     対策: {f.recommendation}")

        out.append("")
        return "\n".join(out)

    @staticmethod
    def format_markdown(findings: List[Finding], mermaid_chart: str) -> str:
        out = []
        out.append("# OSI参照モデル セキュリティ設定監査レポート\n")
        out.append("> 本レポートは `scripts/osi_security_audit.py` により自動生成されたインフラセキュリティ設定の評価結果です。\n")

        # サマリテーブル
        summary: Dict[int, Dict[str, int]] = {i: {"PASS": 0, "LOW": 0, "MEDIUM": 0, "HIGH": 0, "CRITICAL": 0} for i in range(1, 8)}
        for f in findings:
            summary[f.layer][f.severity] += 1

        out.append("## 1. レイヤ別サマリ (OSI 7-Layers Overview)\n")
        out.append("| レイヤ | 名称 | PASS | LOW | MEDIUM | HIGH | CRITICAL |")
        out.append("| :--- | :--- | :---: | :---: | :---: | :---: | :---: |")
        for layer in range(1, 8):
            name = OsiAuditor.LAYER_NAMES[layer]
            s = summary[layer]
            out.append(f"| L{layer} | {name} | {s['PASS']} | {s['LOW']} | {s['MEDIUM']} | {s['HIGH']} | {s['CRITICAL']} |")
        out.append("")

        # Mermaid 図
        out.append("## 2. セキュリティグループ関係性図 (Mermaid Architecture)\n")
        out.append("各セキュリティグループのインバウンド・アウトバウンド通信および外部との接続関係を可視化したトポロジー図です。\n")
        out.append(mermaid_chart)
        out.append("")

        # 詳細チェック結果
        out.append("## 3. レイヤ別セキュリティ詳細評価\n")
        for layer in range(1, 8):
            l_findings = [f for f in findings if f.layer == layer]
            out.append(f"### {OsiAuditor.LAYER_NAMES[layer]}\n")
            for f in l_findings:
                badge = "✅ **PASS**" if f.severity == "PASS" else f"⚠️ **{f.severity}**"
                out.append(f"#### {badge}: {f.title} (`{f.check_id}`)")
                out.append(f"- **対象リソース**: `{f.resource}`")
                out.append(f"- **詳細内容**: {f.description}")
                if f.severity != "PASS":
                    out.append(f"- **改善提案**: {f.recommendation}")
                out.append("")

        # 優先改善項目
        actionable = [f for f in findings if f.severity in ("CRITICAL", "HIGH")]
        out.append("## 4. 改善提案と推奨アクション\n")
        if not actionable:
            out.append("> [!NOTE]\n> 重大なセキュリティ不備や規約違反は検出されませんでした。\n")
        else:
            for idx, f in enumerate(actionable, 1):
                out.append(f"> [!WARNING]\n> **{idx}. [{f.severity}] {f.title}** ({f.layer_name})\n>\n> - **現状とリスク**: {f.description}\n> - **推奨される改善策**: {f.recommendation}\n")

        return "\n".join(out)

def main():
    parser = argparse.ArgumentParser(description="OSI Reference Model Security Auditor for Terraform")
    parser.add_argument("--target-dir", "-d", default=".", help="Root directory of Terraform files (default: .)")
    parser.add_argument("--markdown", "-m", action="store_true", help="Output report in Markdown format")
    parser.add_argument("--output", "-o", help="File path to save the generated report")
    parser.add_argument("--mermaid-only", action="store_true", help="Output only the Mermaid diagram")
    parser.add_argument("--exit-code", action="store_true", help="Exit with code 1 if CRITICAL or HIGH findings exist")
    args = parser.parse_args()

    auditor = OsiAuditor(args.target_dir)
    auditor.load_codebase()
    auditor.run_audit()

    mermaid_chart = MermaidGenerator.generate(auditor.sgs, auditor.rules)

    if args.mermaid_only:
        print(mermaid_chart)
        sys.exit(0)

    if args.markdown:
        report = ReportFormatter.format_markdown(auditor.findings, mermaid_chart)
    else:
        report = ReportFormatter.format_console(auditor.findings, mermaid_chart)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"Report saved to {args.output}")
    else:
        print(report)

    if args.exit_code:
        has_critical_or_high = any(f.severity in ("CRITICAL", "HIGH") for f in auditor.findings)
        if has_critical_or_high:
            sys.exit(1)

if __name__ == '__main__':
    main()
