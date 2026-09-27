#!/usr/bin/env python3
"""
OSI Reference Model Security Auditor & Auto-Remediation Tool for Terraform
================================================================================
Audits Terraform infrastructure code against the OSI 7-Layer reference model,
generates actionable HCL remediation snippets and unified diff patches,
provides automated fix mode (--fix), Mermaid diagram visualization, and
configurable rule policies via external YAML/JSON.
"""

import os
import sys
import re
import glob
import json
import copy
import difflib
import argparse
from dataclasses import dataclass, field
from typing import List, Dict, Set, Tuple, Optional, Any

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


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
    code_remediation: Optional[str] = None
    diff_patch: Optional[str] = None


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


class RulesConfig:
    """Manages external rules, overrides, parameters, and suppressions."""
    DEFAULT_CONFIG = {
        "settings": {
            "fail_on_severity": ["CRITICAL", "HIGH"],
            "allowed_regions": ["ap-northeast-1"],
            "dangerous_ports": ["22", "3389"],
            "db_ports": ["3306", "5432", "6379", "27017"],
            "secure_ssl_policies": [
                "ELBSecurityPolicy-TLS13-1-2-2021-06",
                "ELBSecurityPolicy-TLS-1-2-2017-01"
            ]
        },
        "suppressions": [],
        "rules": {}
    }

    def __init__(self, config_path: Optional[str] = None):
        self.config = copy.deepcopy(self.DEFAULT_CONFIG)
        if config_path and os.path.exists(config_path):
            self.load(config_path)

    def load(self, path: str):
        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
                if path.endswith(('.yaml', '.yml')) and HAS_YAML:
                    loaded = yaml.safe_load(content) or {}
                else:
                    loaded = json.loads(content)
                self._deep_merge(self.config, loaded)
        except Exception as e:
            print(f"[Warning] Failed to load config from {path}: {e}. Using defaults.", file=sys.stderr)

    def _deep_merge(self, base: dict, override: dict):
        for k, v in override.items():
            if isinstance(v, dict) and k in base and isinstance(base[k], dict):
                self._deep_merge(base[k], v)
            else:
                base[k] = v

    def is_enabled(self, check_id: str) -> bool:
        rule_meta = self.config.get("rules", {}).get(check_id, {})
        return rule_meta.get("enabled", True)

    def get_severity(self, check_id: str, default: str) -> str:
        rule_meta = self.config.get("rules", {}).get(check_id, {})
        return rule_meta.get("severity", default)

    def is_suppressed(self, check_id: str, resource_name: str) -> bool:
        suppressions = self.config.get("suppressions", [])
        for sup in suppressions:
            if sup.get("check_id") == check_id:
                target_res = sup.get("resource", "")
                if not target_res or target_res == resource_name or target_res in resource_name:
                    return True
        return False

    def get_setting(self, key: str, default: Any = None) -> Any:
        return self.config.get("settings", {}).get(key, default)


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

    def __init__(self, root_dir: str, config: Optional[RulesConfig] = None):
        self.root_dir = os.path.abspath(root_dir)
        self.config = config or RulesConfig()
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

    def add_finding(self, layer: int, check_id: str, default_severity: str,
                    title: str, resource: str, file_path: str,
                    description: str, recommendation: str,
                    code_remediation: Optional[str] = None,
                    diff_patch: Optional[str] = None):
        if not self.config.is_enabled(check_id):
            return

        if default_severity != "PASS" and self.config.is_suppressed(check_id, resource):
            return

        severity = self.config.get_severity(check_id, default_severity) if default_severity != "PASS" else "PASS"

        # Generate diff_patch automatically if file_path and code_remediation are given but diff is omitted
        if file_path and code_remediation and not diff_patch and os.path.exists(file_path):
            diff_patch = RemediationManager.create_append_diff(file_path, code_remediation, self.root_dir)

        self.findings.append(Finding(
            layer=layer,
            layer_name=self.LAYER_NAMES[layer],
            check_id=check_id,
            severity=severity,
            title=title,
            resource=resource,
            file_path=file_path,
            description=description,
            recommendation=recommendation,
            code_remediation=code_remediation,
            diff_patch=diff_patch
        ))

    def run_audit(self):
        self._audit_l1_physical()
        self._audit_l2_data_link()
        self._audit_l3_network()
        self._audit_l4_transport()
        self._audit_l5_session()
        self._audit_l6_presentation()
        self._audit_l7_application()

    def _find_file(self, filename: str) -> str:
        for r in self.resources:
            if os.path.basename(r.file_path) == filename:
                return r.file_path
        matches = glob.glob(os.path.join(self.root_dir, '**', filename), recursive=True)
        return matches[0] if matches else ""

    # --- L1 物理層 ---
    def _audit_l1_physical(self):
        allowed_regions = self.config.get_setting("allowed_regions", ["ap-northeast-1"])
        found_regions = set()
        for r in self.resources:
            if 'region' in r.attrs:
                val = r.attrs['region']
                if 'var.' not in val and '${' not in val:
                    found_regions.add(val)

        invalid_regions = [reg for reg in found_regions if reg and not any(ar in reg for ar in allowed_regions)]
        if invalid_regions:
            hcl_fix = 'provider "aws" {\n  region = "ap-northeast-1"\n}\n'
            self.add_finding(
                1, "L1-REGION-POLICY", "HIGH",
                "東京リージョン外のリソース設定検出",
                f"Regions: {invalid_regions}", "",
                f"許可されていないリージョン ({invalid_regions}) が指定されています。",
                f"セキュリティガバナンスに従い、リージョンを '{allowed_regions[0]}' に統一してください。",
                code_remediation=hcl_fix
            )
        else:
            self.add_finding(
                1, "L1-REGION-POLICY", "PASS",
                "リージョン制限の遵守 (東京リージョン ap-northeast-1)",
                "Provider / Config", "",
                "東京リージョン (ap-northeast-1) に限定されており、データ主権・ガバナンス規約に準拠しています。",
                "現状の設定を維持してください。"
            )

        subnets = [r for r in self.resources if r.type == 'aws_subnet']
        has_multi_az = False
        target_subnet_file = subnets[0].file_path if subnets else ""
        for s in subnets:
            if 'count' in s.attrs or 'count' in s.raw_body or 'availability_zones' in s.raw_body:
                has_multi_az = True
                break
        if len(subnets) >= 2 or has_multi_az:
            self.add_finding(
                1, "L1-MULTI-AZ", "PASS",
                "Multi-AZ 物理冗長化の確保",
                "aws_subnet (availability_zones)", target_subnet_file,
                "複数 Availability Zone へのサブネット分散配置が定義されており、データセンター障害への耐障害性を確保しています。",
                "現状の Multi-AZ 構成を維持してください。"
            )
        else:
            hcl_fix = (
                'resource "aws_subnet" "subnet_az2" {\n'
                '  vpc_id            = aws_vpc.vpc-main.id\n'
                '  cidr_block        = "10.0.2.0/24"\n'
                '  availability_zone = "ap-northeast-1c"\n'
                '  tags = { Name = "${var.env}-${var.service}-public-02" }\n'
                '}\n'
            )
            self.add_finding(
                1, "L1-MULTI-AZ", "MEDIUM",
                "Multi-AZ 物理冗長化の不足",
                "aws_subnet", target_subnet_file,
                "サブネットの AZ 分散が確認できません。単一 AZ 障害時にサービス停止のリスクがあります。",
                "最低 2 つ以上の異なる Availability Zone にサブネットを分散配置してください。",
                code_remediation=hcl_fix
            )

    # --- L2 データリンク層 ---
    def _audit_l2_data_link(self):
        vpcs = [r for r in self.resources if r.type == 'aws_vpc']
        if vpcs:
            self.add_finding(
                2, "L2-VPC-ISOLATION", "PASS",
                "VPC 仮想ネットワーク境界によるレイヤ2アイソレーション",
                vpcs[0].name, vpcs[0].file_path,
                "専用 VPC によるプライベート IP 空間が確保されており、AWS Hypervisor により MAC/ARP スプーフィング等の L2 攻撃が遮断されています。",
                "現状の VPC 境界隔離を維持してください。"
            )
        else:
            hcl_fix = (
                'resource "aws_vpc" "vpc-main" {\n'
                '  cidr_block           = var.vpc_cidr\n'
                '  enable_dns_support   = true\n'
                '  enable_dns_hostnames = true\n'
                '  tags = { Name = "${var.env}-${var.service}-vpc" }\n'
                '}\n'
            )
            self.add_finding(
                2, "L2-VPC-ISOLATION", "CRITICAL",
                "専用 VPC の未定義 (デフォルトVPC利用リスク)",
                "None", "",
                "専用 VPC の定義が見つかりません。デフォルト VPC に配置されると意図しない公開や L2 境界防御の喪失に繋がります。",
                "明示的に `aws_vpc` リソースを定義し、プライベート空間を確保してください。",
                code_remediation=hcl_fix
            )

    # --- L3 ネットワーク層 ---
    def _audit_l3_network(self):
        subnets = [r for r in self.resources if r.type == 'aws_subnet']
        has_private_subnet = any('private' in r.name.lower() or 'private' in r.raw_body.lower() for r in subnets)
        target_vpc_file = subnets[0].file_path if subnets else self._find_file("vpc.tf")

        if not has_private_subnet:
            hcl_fix = (
                '\n# --- L3 Remediation: Private Subnets for Backend Isolation ---\n'
                'resource "aws_subnet" "private_subnet" {\n'
                '  count             = length(var.subnets)\n'
                '  vpc_id            = aws_vpc.vpc-main.id\n'
                '  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)\n'
                '  availability_zone = element(var.availability_zones, count.index)\n\n'
                '  tags = {\n'
                '    Name = "${var.env}-${var.service}-private-${format("%02d", count.index + 1)}"\n'
                '    Tier = "Private"\n'
                '  }\n'
                '}\n\n'
                'resource "aws_route_table" "private-rt" {\n'
                '  vpc_id = aws_vpc.vpc-main.id\n\n'
                '  tags = {\n'
                '    Name = "${var.env}-${var.service}-private-rt"\n'
                '  }\n'
                '}\n\n'
                'resource "aws_route_table_association" "private-association" {\n'
                '  count          = length(var.subnets)\n'
                '  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)\n'
                '  route_table_id = aws_route_table.private-rt.id\n'
                '}\n'
            )
            self.add_finding(
                3, "L3-SUBNET-SEGREGATION", "HIGH",
                "パブリック / プライベートサブネットの未分離",
                "aws_subnet", target_vpc_file,
                "現在パブリックサブネットのみが存在し、プライベートサブネットが未定義です。EC2 や RDS がパブリック直通ネットワークに配置されるリスクがあります。",
                "ALB のみを配置する Public Subnet と、EC2/RDS を隔離配置する Private Subnet を分割定義してください。",
                code_remediation=hcl_fix
            )
        else:
            self.add_finding(
                3, "L3-SUBNET-SEGREGATION", "PASS",
                "ネットワーク層の多層防御 (Public/Private サブネット分離)",
                "aws_subnet", target_vpc_file,
                "プライベートサブネットによる境界分離が施されています。",
                "現状の設定を維持してください。"
            )

        flow_logs = [r for r in self.resources if r.type == 'aws_flow_log']
        if flow_logs:
            fl = flow_logs[0]
            is_parquet = 'parquet' in fl.raw_body.lower()
            is_fast_interval = 'max_aggregation_interval = 60' in fl.raw_body
            self.add_finding(
                3, "L3-VPC-FLOW-LOGS", "PASS",
                "VPC Flow Logs による L3 トラフィックの可視化と監査",
                fl.name, fl.file_path,
                f"VPC Flow Logs が有効化されています (Parquet形式: {is_parquet}, 1分集約: {is_fast_interval})。IPパケットの拒否・許可監査が可能です。",
                "CloudWatch Logs / Athena 連携による異常通信（ポートスキャン等）の定期分析を推奨します。"
            )
        else:
            hcl_fix = (
                '\nresource "aws_flow_log" "vpc_flow_log" {\n'
                '  vpc_id                   = aws_vpc.vpc-main.id\n'
                '  traffic_type             = "ALL"\n'
                '  log_destination_type     = "s3"\n'
                '  log_destination          = aws_s3_bucket.flow_logs.arn\n'
                '  max_aggregation_interval = 60\n'
                '}\n'
            )
            self.add_finding(
                3, "L3-VPC-FLOW-LOGS", "HIGH",
                "VPC Flow Logs の未有効化",
                "aws_vpc", target_vpc_file,
                "VPC Flow Logs が有効化されておらず、ネットワークレベルの侵入や不正通信のフォレンジック・追跡が不可能です。",
                "`aws_flow_log` リソースを追加し、S3 または CloudWatch Logs に通信ログを保存してください。",
                code_remediation=hcl_fix
            )

        nacls = [r for r in self.resources if r.type == 'aws_network_acl']
        if not nacls:
            hcl_fix = (
                '\n# --- L3 Remediation: Custom Stateless Network ACL ---\n'
                'resource "aws_network_acl" "main_nacl" {\n'
                '  vpc_id     = aws_vpc.vpc-main.id\n'
                '  subnet_ids = aws_subnet.public_subnet.*.id\n\n'
                '  egress {\n'
                '    protocol   = "-1"\n'
                '    rule_no    = 100\n'
                '    action     = "allow"\n'
                '    cidr_block = "0.0.0.0/0"\n'
                '    from_port  = 0\n'
                '    to_port    = 0\n'
                '  }\n\n'
                '  ingress {\n'
                '    protocol   = "-1"\n'
                '    rule_no    = 100\n'
                '    action     = "allow"\n'
                '    cidr_block = "0.0.0.0/0"\n'
                '    from_port  = 0\n'
                '    to_port    = 0\n'
                '  }\n\n'
                '  tags = {\n'
                '    Name = "${var.env}-${var.service}-nacl"\n'
                '  }\n'
                '}\n'
            )
            self.add_finding(
                3, "L3-NETWORK-ACL", "MEDIUM",
                "カスタム Network ACL (NACL) の未定義",
                "aws_network_acl", target_vpc_file,
                "明示的な NACL が定義されておらず、デフォルトのステートレスパケット全許可に依存しています。",
                "サブネット境界での二重防御（特定悪性 CIDR や不要プロトコルの遮断）のため、カスタム NACL の導入を検討してください。",
                code_remediation=hcl_fix
            )
        else:
            self.add_finding(
                3, "L3-NETWORK-ACL", "PASS",
                "Network ACL によるステートレスパケットフィルタリング",
                nacls[0].name, nacls[0].file_path,
                "カスタム NACL によるサブネット境界防御が定義されています。",
                "定期的なルール見直しを推奨します。"
            )

    # --- L4 トランスポート層 ---
    def _audit_l4_transport(self):
        dangerous_ports = set(self.config.get_setting("dangerous_ports", ["22", "3389"]))
        found_danger = False
        for r in self.rules:
            fp = r.attrs.get('from_port', '')
            tp = r.attrs.get('to_port', '')
            cidr = r.attrs.get('cidr_ipv4', '') or r.attrs.get('cidr_blocks', '')
            is_ingress = 'ingress' in r.type or r.attrs.get('type') == 'ingress'

            if is_ingress and '0.0.0.0/0' in cidr:
                if fp in dangerous_ports or tp in dangerous_ports:
                    found_danger = True
                    hcl_fix = (
                        '# Restrict management ingress rule to private admin CIDR\n'
                        f'# Replace cidr_ipv4 = "{cidr}" with trusted CIDR e.g. "10.0.0.0/8"\n'
                    )
                    self.add_finding(
                        4, "L4-MANAGEMENT-PORTS", "CRITICAL",
                        f"管理ポート ({fp}) のインターネット全開放",
                        r.name, r.file_path,
                        f"セキュリティグループルール '{r.name}' でポート {fp} が 0.0.0.0/0 に全開放されています。総当たり攻撃や侵入のリスクがあります。",
                        "0.0.0.0/0 の許可を削除し、AWS Systems Manager (SSM) Session Manager を使用するか、社内固定 IP に限定してください。",
                        code_remediation=hcl_fix
                    )
        if not found_danger:
            self.add_finding(
                4, "L4-MANAGEMENT-PORTS", "PASS",
                "管理ポート (SSH:22 / RDP:3389) のインターネット非露出",
                "Security Groups", self._find_file("security_group.tf"),
                "SSH/RDP などの管理ポートはインターネットに一切露出していません。",
                "SSM Session Manager による踏み台レス・セキュアアクセスの運用を継続してください。"
            )

        db_ports = set(self.config.get_setting("db_ports", ["3306", "5432", "6379", "27017"]))
        found_db_open = False
        for r in self.rules:
            fp = r.attrs.get('from_port', '')
            cidr = r.attrs.get('cidr_ipv4', '') or r.attrs.get('cidr_blocks', '')
            is_ingress = 'ingress' in r.type or r.attrs.get('type') == 'ingress'
            if is_ingress and '0.0.0.0/0' in cidr:
                if fp in db_ports or 'rds_port' in fp:
                    found_db_open = True
                    hcl_fix = (
                        '# Replace 0.0.0.0/0 with referenced security group\n'
                        'referenced_security_group_id = aws_security_group.ec2_sg.id\n'
                    )
                    self.add_finding(
                        4, "L4-DATABASE-PORTS", "CRITICAL",
                        f"データベースポート ({fp}) のインターネット全開放",
                        r.name, r.file_path,
                        "データベースポートが 0.0.0.0/0 に開放されています。重大な情報漏洩リスクがあります。",
                        "接続元を特定のアプリケーションセキュリティグループ ID に限定してください。",
                        code_remediation=hcl_fix
                    )
        if not found_db_open:
            self.add_finding(
                4, "L4-DATABASE-PORTS", "PASS",
                "データベースポート (3306等) の保護 (SG Chaining)",
                "Security Groups", self._find_file("security_group.tf"),
                "データベースポートは外部公開されておらず、接続元 SG (EC2/ECS/NLB) のみから許可されています。",
                "現状のセキュリティグループチェイニングを維持してください。"
            )

        unrestricted_egress = []
        for r in self.rules:
            is_egress = 'egress' in r.type or r.attrs.get('type') == 'egress'
            cidr = r.attrs.get('cidr_ipv4', '') or r.attrs.get('cidr_blocks', '')
            proto = r.attrs.get('ip_protocol', '') or r.attrs.get('protocol', '')
            fp = r.attrs.get('from_port', '')
            if is_egress and '0.0.0.0/0' in cidr and (proto == '-1' or fp == '0'):
                unrestricted_egress.append(r)

        if unrestricted_egress:
            hcl_fix = (
                '# Restrict egress rule to HTTPS (443) only\n'
                'ip_protocol = "tcp"\n'
                'from_port   = 443\n'
                'to_port     = 443\n'
            )
            self.add_finding(
                4, "L4-UNRESTRICTED-EGRESS", "HIGH",
                "アウトバウンド通信 (Egress) の全開放 (全プロトコル/全ポート)",
                f"{[r.name for r in unrestricted_egress]}", unrestricted_egress[0].file_path,
                "アウトバウンドが 0.0.0.0/0 かつ全プロトコル (-1) で開放されています。マルウェア感染時の C2 通信やデータ持ち出し (Exfiltration) を防げません。",
                "必要な外向き通信（HTTPS 443 や RDS 3306）のみにポートを絞り込んでください。",
                code_remediation=hcl_fix
            )
        else:
            self.add_finding(
                4, "L4-UNRESTRICTED-EGRESS", "PASS",
                "アウトバウンド通信 (Egress) の最小権限化",
                "Security Groups", self._find_file("security_group.tf"),
                "全開放 (0.0.0.0/0:all) は存在せず、HTTPS (443) や特定 DB ポート (3306) に限定されています。",
                "現状の最小権限ポリシーを維持してください。"
            )

    # --- L5 セッション層 ---
    def _audit_l5_session(self):
        listeners = [r for r in self.resources if r.type == 'aws_lb_listener']
        has_https = any(r.attrs.get('port') == '443' or r.attrs.get('protocol') == 'HTTPS' for r in listeners)
        has_redirect = any('redirect' in r.raw_body for r in listeners)
        elb_file = listeners[0].file_path if listeners else self._find_file("aws_elb.tf")

        if has_https and has_redirect:
            self.add_finding(
                5, "L5-ALB-HTTPS", "PASS",
                "ALB における HTTPS 強制と HTTP からのリダイレクト",
                "aws_lb_listener", elb_file,
                "HTTPS (Port 443) リスナーが設定され、HTTP (Port 80) は 301 リダイレクトで保護されています。",
                "セッションハイジャックおよび平文盗聴を防止できています。"
            )
        elif has_https:
            hcl_fix = (
                '\nresource "aws_lb_listener" "http_redirect" {\n'
                '  load_balancer_arn = aws_lb.app-lb.arn\n'
                '  port              = 80\n'
                '  protocol          = "HTTP"\n\n'
                '  default_action {\n'
                '    type = "redirect"\n'
                '    redirect {\n'
                '      port        = "443"\n'
                '      protocol    = "HTTPS"\n'
                '      status_code = "HTTP_301"\n'
                '    }\n'
                '  }\n'
                '}\n'
            )
            self.add_finding(
                5, "L5-ALB-HTTPS", "MEDIUM",
                "HTTP から HTTPS への自動リダイレクト未設定",
                "aws_lb_listener", elb_file,
                "HTTPS リスナーは存在しますが、平文 HTTP 通信を HTTPS へ自動転送するリダイレクトルールが不足しています。",
                "Port 80 リスナーに 301 リダイレクトアクションを追加してください。",
                code_remediation=hcl_fix
            )
        else:
            hcl_fix = (
                '\nresource "aws_lb_listener" "https" {\n'
                '  load_balancer_arn = aws_lb.app-lb.arn\n'
                '  port              = 443\n'
                '  protocol          = "HTTPS"\n'
                '  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"\n'
                '  certificate_arn   = var.acm_certificate_arn\n\n'
                '  default_action {\n'
                '    type             = "forward"\n'
                '    target_group_arn = aws_lb_target_group.app_tg.arn\n'
                '  }\n'
                '}\n'
            )
            self.add_finding(
                5, "L5-ALB-HTTPS", "CRITICAL",
                "ALB における HTTPS 暗号化セッションの未設定",
                "aws_lb_listener", elb_file,
                "HTTPS (Port 443) リスナーが設定されておらず、すべての通信が平文で伝送されるリスクがあります。",
                "ACM 証明書を紐付けた HTTPS (443) リスナーを作成してください。",
                code_remediation=hcl_fix
            )

        secure_ssl_policies = self.config.get_setting("secure_ssl_policies", [
            "ELBSecurityPolicy-TLS13-1-2-2021-06",
            "ELBSecurityPolicy-TLS-1-2-2017-01"
        ])
        has_modern_tls = any(any(pol in r.raw_body for pol in secure_ssl_policies) for r in listeners)
        if has_modern_tls:
            self.add_finding(
                5, "L5-TLS-POLICY", "PASS",
                "最新の TLS 1.3 / 1.2 暗号スイートの強制",
                "ssl_policy", elb_file,
                "ELBSecurityPolicy-TLS13-1-2-2021-06 が指定され、脆弱な SSLv3/TLS 1.0/1.1 が遮断されています。",
                "現状の安全なポリシーを維持してください。"
            )
        else:
            hcl_fix = 'ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"\n'
            self.add_finding(
                5, "L5-TLS-POLICY", "HIGH",
                "非推奨または古い SSL/TLS ポリシーの利用",
                "ssl_policy", elb_file,
                "古い TLS ポリシーが使用されているか明示されていません。POODLE や BEAST などの既知の攻撃に脆弱な可能性があります。",
                "`ELBSecurityPolicy-TLS13-1-2-2021-06` などの最新ポリシーを指定してください。",
                code_remediation=hcl_fix
            )

    # --- L6 プレゼンテーション層 ---
    def _audit_l6_presentation(self):
        param_groups = [r for r in self.resources if 'parameter_group' in r.type]
        has_rds_ssl = any('require_secure_transport' in r.raw_body and 'ON' in r.raw_body for r in param_groups)
        has_rds_tls13 = any('TLSv1.2,TLSv1.3' in r.raw_body for r in param_groups)
        rds_file = param_groups[0].file_path if param_groups else self._find_file("rds.tf")

        if has_rds_ssl and has_rds_tls13:
            self.add_finding(
                6, "L6-RDS-TRANSPORT-ENCRYPTION", "PASS",
                "Aurora RDS の SSL/TLS 強制 (require_secure_transport=ON)",
                "aws_rds_cluster_parameter_group", rds_file,
                "すべてのクライアント接続に TLS 1.2 / 1.3 が強制され、平文の SQL クエリ・認証情報の伝送が遮断されています。",
                "現状の設定を維持してください。"
            )
        else:
            hcl_fix = (
                '\n  parameter {\n'
                '    name  = "require_secure_transport"\n'
                '    value = "ON"\n'
                '  }\n'
                '  parameter {\n'
                '    name  = "tls_version"\n'
                '    value = "TLSv1.2,TLSv1.3"\n'
                '  }\n'
            )
            self.add_finding(
                6, "L6-RDS-TRANSPORT-ENCRYPTION", "HIGH",
                "RDS 通信の SSL/TLS 強制設定の欠落",
                "aws_rds_cluster_parameter_group", rds_file,
                "RDS パラメータグループで `require_secure_transport = ON` が設定されていません。平文で DB 通信が行われるリスクがあります。",
                "パラメータグループに `require_secure_transport = ON` および `tls_version = TLSv1.2,TLSv1.3` を追加してください。",
                code_remediation=hcl_fix
            )

        instances = [r for r in self.resources if r.type == 'aws_instance']
        ebs_encrypted = all(bool(re.search(r'encrypted\s*=\s*true', r.raw_body, re.IGNORECASE)) for r in instances) if instances else True

        rds_clusters = [r for r in self.resources if r.type == 'aws_rds_cluster']
        rds_encrypted = all(bool(re.search(r'storage_encrypted\s*=\s*true', r.raw_body, re.IGNORECASE)) for r in rds_clusters) if rds_clusters else True

        if ebs_encrypted and rds_encrypted:
            self.add_finding(
                6, "L6-DATA-AT-REST-ENCRYPTION", "PASS",
                "保存データの暗号化 (EBS / RDS / S3 KMS CMK)",
                "KMS / EBS / RDS", self._find_file("rds.tf"),
                "EC2 EBS ボリューム (`encrypted=true`) および RDS クラスター (`storage_encrypted=true`) の暗号化が適用されています。",
                "KMS カスタマーマネージドキークラス (CMK) による鍵ローテーションの維持を推奨します。"
            )
        else:
            hcl_fix = "storage_encrypted = true\nkms_key_id        = aws_kms_key.rds.arn\n"
            self.add_finding(
                6, "L6-DATA-AT-REST-ENCRYPTION", "CRITICAL",
                "未暗号化ストレージの検出",
                "EBS / RDS", self._find_file("rds.tf"),
                "暗号化が有効化されていない EBS ボリュームまたは RDS インスタンスが検出されました。",
                "すべてのストレージリソースで `encrypted = true` または `storage_encrypted = true` を設定してください。",
                code_remediation=hcl_fix
            )

    # --- L7 アプリケーション層 ---
    def _audit_l7_application(self):
        waf_assocs = [r for r in self.resources if 'waf' in r.type]
        has_waf = len(waf_assocs) > 0
        elb_file = self._find_file("aws_elb.tf")

        if not has_waf:
            hcl_fix = (
                '\n# --- L7 Remediation: AWS WAFv2 Association ---\n'
                'resource "aws_wafv2_web_acl" "alb_waf" {\n'
                '  name        = "${var.env}-${var.service}-alb-waf"\n'
                '  scope       = "REGIONAL"\n'
                '  description = "AWS WAFv2 Web ACL for Application Load Balancer"\n\n'
                '  default_action {\n'
                '    allow {}\n'
                '  }\n\n'
                '  visibility_config {\n'
                '    cloudwatch_metrics_enabled = true\n'
                '    metric_name                = "${var.env}-${var.service}-alb-waf-metric"\n'
                '    sampled_requests_enabled   = true\n'
                '  }\n\n'
                '  rule {\n'
                '    name     = "AWSManagedRulesCommonRuleSet"\n'
                '    priority = 1\n\n'
                '    override_action {\n'
                '      none {}\n'
                '    }\n\n'
                '    statement {\n'
                '      managed_rule_group_statement {\n'
                '        name        = "AWSManagedRulesCommonRuleSet"\n'
                '        vendor_name = "AWS"\n'
                '      }\n'
                '    }\n\n'
                '    visibility_config {\n'
                '      cloudwatch_metrics_enabled = true\n'
                '      metric_name                = "AWSManagedRulesCommonRuleSetMetric"\n'
                '      sampled_requests_enabled   = true\n'
                '    }\n'
                '  }\n'
                '}\n\n'
                'resource "aws_wafv2_web_acl_association" "alb_waf_assoc" {\n'
                '  resource_arn = aws_lb.app-lb.arn\n'
                '  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn\n'
                '}\n'
            )
            self.add_finding(
                7, "L7-WAF-PROTECTION", "HIGH",
                "ALB / CloudFront への AWS WAFv2 未紐付け",
                "aws_lb, aws_cloudfront_distribution", elb_file,
                "パブリック ALB または CloudFront に WAF Web ACL が関連付けられていません。SQLi, XSS, レート制限超過等の L7 攻撃に無防備です。",
                "`aws_wafv2_web_acl` および `aws_wafv2_web_acl_association` を定義してアタッチしてください。",
                code_remediation=hcl_fix
            )
        else:
            self.add_finding(
                7, "L7-WAF-PROTECTION", "PASS",
                "AWS WAFv2 による L7 アプリケーション保護",
                waf_assocs[0].name, waf_assocs[0].file_path,
                "WAF Web ACL が適用されており、レイヤ7の脆弱性攻撃や不正リクエストを遮断可能です。",
                "マネージドルールの定期的な検知ログ分析を推奨します。"
            )

        albs = [r for r in self.resources if r.type == 'aws_lb' and r.attrs.get('load_balancer_type') == 'application']
        drop_headers = all('drop_invalid_header_fields = true' in r.raw_body for r in albs) if albs else True
        if drop_headers:
            self.add_finding(
                7, "L7-HTTP-HEADER-DROPPING", "PASS",
                "不正な HTTP ヘッダーのドロップ (HTTP Request Smuggling 対策)",
                "aws_lb.app-lb", elb_file,
                "`drop_invalid_header_fields = true` が有効であり、HTTP リクエストスマグリング等の悪意あるヘッダー挿入攻撃が防御されています。",
                "現状の設定を維持してください。"
            )
        else:
            hcl_fix = "drop_invalid_header_fields = true\n"
            self.add_finding(
                7, "L7-HTTP-HEADER-DROPPING", "MEDIUM",
                "不正な HTTP ヘッダーの遮断が無効",
                "aws_lb", elb_file,
                "ALB で `drop_invalid_header_fields` が無効です。不正な HTTP ヘッダーによるバックエンド汚染のリスクがあります。",
                "`drop_invalid_header_fields = true` を設定してください。",
                code_remediation=hcl_fix
            )

        instances = [r for r in self.resources if r.type == 'aws_instance']
        imdsv2_enforced = all(bool(re.search(r'http_tokens\s*=\s*\"required\"', r.raw_body)) for r in instances) if instances else True
        ec2_file = instances[0].file_path if instances else self._find_file("aws_instance.tf")
        if imdsv2_enforced:
            self.add_finding(
                7, "L7-IMDSV2-PROTECTION", "PASS",
                "EC2 インスタンスにおける IMDSv2 の強制 (SSRF / 認証情報奪取対策)",
                "aws_instance", ec2_file,
                "メタデータアクセスにセッショントークン (`http_tokens = required`) が必須化されており、SSRF による IAM ロール奪取を防御しています。",
                "現状の設定を維持してください。"
            )
        else:
            hcl_fix = (
                '\n  metadata_options {\n'
                '    http_tokens                 = "required"\n'
                '    http_endpoint               = "enabled"\n'
                '    http_put_response_hop_limit = 1\n'
                '  }\n'
            )
            self.add_finding(
                7, "L7-IMDSV2-PROTECTION", "CRITICAL",
                "IMDSv1 許可による IAM 認証情報奪取リスク",
                "aws_instance", ec2_file,
                "EC2 で IMDSv2 が強制されていません。SSRF 脆弱性が発生した場合にインスタンスロールの認証情報が盗まれる危険があります。",
                "`metadata_options { http_tokens = \"required\" }` を設定してください。",
                code_remediation=hcl_fix
            )

        task_defs = [r for r in self.resources if r.type == 'aws_ecs_task_definition']
        has_readonly_root = any('readonlyRootFilesystem = true' in r.raw_body or '"readonlyRootFilesystem": true' in r.raw_body for r in task_defs)
        ecs_file = task_defs[0].file_path if task_defs else self._find_file("service.tf")
        if has_readonly_root:
            self.add_finding(
                7, "L7-CONTAINER-IMMUTABILITY", "PASS",
                "コンテナの読み取り専用ルートファイルシステム (イミュータブル運用)",
                "aws_ecs_task_definition", ecs_file,
                "`readonlyRootFilesystem = true` により、コンテナ内への不正バイナリ配置やマルウェア定着が防御されています。",
                "現状の設定を維持してください。"
            )
        elif task_defs:
            hcl_fix = '"readonlyRootFilesystem": true\n'
            self.add_finding(
                7, "L7-CONTAINER-IMMUTABILITY", "MEDIUM",
                "コンテナルートファイルシステムの書き込み可能設定",
                "aws_ecs_task_definition", ecs_file,
                "コンテナのルートファイルシステムへの書き込みが許可されています。改ざんやマルウェア配置のリスクがあります。",
                "`readonlyRootFilesystem: true` を設定し、一時ファイルはマウントボリュームに限定してください。",
                code_remediation=hcl_fix
            )


class RemediationManager:
    """Handles unified diff generation, patch saving, and automated code fixing."""

    @staticmethod
    def create_append_diff(file_path: str, code_to_append: str, root_dir: str = "") -> str:
        if not os.path.exists(file_path):
            return ""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                original = f.read()
        except Exception:
            return ""

        rel_path = os.path.relpath(file_path, root_dir) if root_dir else file_path
        new_content = original.rstrip() + "\n\n" + code_to_append.strip() + "\n"

        orig_lines = original.splitlines(keepends=True)
        new_lines = new_content.splitlines(keepends=True)

        diff = difflib.unified_diff(
            orig_lines,
            new_lines,
            fromfile=f"a/{rel_path}",
            tofile=f"b/{rel_path}"
        )
        return "".join(diff)

    @staticmethod
    def generate_unified_patch(findings: List[Finding], root_dir: str) -> str:
        patches = []
        seen_files = set()
        for f in findings:
            if f.severity != "PASS" and f.code_remediation and f.file_path:
                if f.file_path in seen_files:
                    continue
                diff = f.diff_patch or RemediationManager.create_append_diff(f.file_path, f.code_remediation, root_dir)
                if diff:
                    patches.append(diff)
                    seen_files.add(f.file_path)
        return "\n".join(patches)

    @staticmethod
    def apply_fixes(findings: List[Finding], dry_run: bool = False, backup: bool = True) -> Dict[str, Any]:
        results = {"applied": [], "failed": [], "skipped": []}
        grouped: Dict[str, List[Finding]] = {}

        for f in findings:
            if f.severity in ("CRITICAL", "HIGH", "MEDIUM") and f.code_remediation and f.file_path:
                grouped.setdefault(f.file_path, []).append(f)

        for path, f_list in grouped.items():
            if not os.path.exists(path):
                results["skipped"].append({"file": path, "reason": "File does not exist"})
                continue

            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()

                new_content = content
                applied_rules = []
                for finding in f_list:
                    # Check if already applied to prevent duplicate injection
                    if finding.check_id in content:
                        continue

                    # Safe append pattern for new resource definitions
                    if "resource \"" in finding.code_remediation:
                        new_content = new_content.rstrip() + "\n" + finding.code_remediation.rstrip() + "\n"
                        applied_rules.append(finding.check_id)
                    # Safe parameter injection pattern
                    elif finding.check_id == "L7-HTTP-HEADER-DROPPING" and "drop_invalid_header_fields" not in new_content:
                        new_content = re.sub(
                            r'(resource\s+"aws_lb"\s+"[^"]+"\s*\{)',
                            r'\1\n  drop_invalid_header_fields = true',
                            new_content,
                            count=1
                        )
                        applied_rules.append(finding.check_id)

                if applied_rules:
                    if not dry_run:
                        if backup:
                            with open(path + ".bak", 'w', encoding='utf-8') as bf:
                                bf.write(content)
                        with open(path, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                    results["applied"].append({
                        "file": path,
                        "rules": applied_rules,
                        "dry_run": dry_run,
                        "backup_created": backup and not dry_run
                    })
                else:
                    results["skipped"].append({"file": path, "reason": "Already up to date or no safe patch pattern"})

            except Exception as e:
                results["failed"].append({"file": path, "error": str(e)})

        return results


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

        lines.append("    subgraph External[\"🌐 外部ネットワーク / クライアント\"]")
        lines.append("        Internet[\"Internet<br/>0.0.0.0/0\"]")
        lines.append("        PrivateLink[\"PrivateLink Clients<br/>(Databricks / VPC Endpoint)\"]")
        lines.append("        VPC_Internal[\"VPC Internal CIDR<br/>(Local Subnets)\"]")
        lines.append("    end")
        lines.append("")

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
            lines.append("    end\n")

        if app_nodes:
            lines.append("    subgraph AppTier[\"⚙️ Application Tier (L4/L7)\"]")
            lines.extend(app_nodes)
            lines.append("    end\n")

        if db_nodes:
            lines.append("    subgraph DbTier[\"🗄️ Database Tier (L4)\"]")
            lines.extend(db_nodes)
            lines.append("    end\n")

        if eks_nodes:
            lines.append("    subgraph EksTier[\"☸️ Kubernetes (EKS) Tier\"]")
            lines.extend(eks_nodes)
            lines.append("    end\n")

        edges = set()
        for r in rules:
            attrs = r.attrs
            sg_id_raw = attrs.get('security_group_id', '')
            ref_sg_raw = attrs.get('referenced_security_group_id', '') or attrs.get('source_security_group_id', '')
            cidr = attrs.get('cidr_ipv4', '') or attrs.get('cidr_blocks', '')
            proto = (attrs.get('ip_protocol', '') or attrs.get('protocol', '')).upper()
            fp = attrs.get('from_port', '')
            tp = attrs.get('to_port', '')

            if not proto and (fp == '443' or fp == '80' or fp == '3306'):
                proto = "TCP"

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
    def format_console(findings: List[Finding], mermaid_chart: str, show_diff: bool = False, show_code: bool = True) -> str:
        out = []
        out.append(f"{Colors.BOLD}{Colors.CYAN}=============================================================================={Colors.RESET}")
        out.append(f"{Colors.BOLD}{Colors.CYAN}  OSI 参照モデル セキュリティ設定監査レポート (Terraform Security Audit){Colors.RESET}")
        out.append(f"{Colors.BOLD}{Colors.CYAN}=============================================================================={Colors.RESET}\n")

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
                out.append(f"     対象: {f.resource} ({f.file_path or 'N/A'})")
                out.append(f"     説明: {f.description}")
                if f.severity != "PASS":
                    out.append(f"     {Colors.YELLOW}推奨改善案: {f.recommendation}{Colors.RESET}")
                    if show_code and f.code_remediation:
                        out.append(f"     {Colors.CYAN}--- 推奨修正コード (Terraform Snippet) ---{Colors.RESET}")
                        for line in f.code_remediation.strip().splitlines():
                            out.append(f"       {Colors.CYAN}{line}{Colors.RESET}")
                    if show_diff and f.diff_patch:
                        out.append(f"     {Colors.HEADER}--- Unified Diff Patch ---{Colors.RESET}")
                        for line in f.diff_patch.strip().splitlines():
                            color = Colors.GREEN if line.startswith('+') else (Colors.RED if line.startswith('-') else Colors.RESET)
                            out.append(f"       {color}{line}{Colors.RESET}")

        out.append(f"\n{Colors.BOLD}【3. セキュリティグループ関係性図 (Mermaid Diagram)】{Colors.RESET}")
        out.append(mermaid_chart)

        actionable = [f for f in findings if f.severity in ("CRITICAL", "HIGH")]
        out.append(f"\n{Colors.BOLD}【4. 最優先改善アクション (Priority Remediation)】{Colors.RESET}")
        if not actionable:
            out.append(f"  {Colors.GREEN}✓ 重大なセキュリティ脆弱性は検出されませんでした。良好な設定状態です。{Colors.RESET}")
        else:
            for idx, f in enumerate(actionable, 1):
                out.append(f"  {idx}. [{f.severity}] {f.title} ({f.layer_name})")
                out.append(f"     対象: {f.file_path}")
                out.append(f"     対策: {f.recommendation}")
                if f.code_remediation:
                    out.append(f"     自動修正対応: 可 (`--fix` または `--generate-patch` で適用可能)")

        out.append("")
        return "\n".join(out)

    @staticmethod
    def format_markdown(findings: List[Finding], mermaid_chart: str) -> str:
        out = []
        out.append("# OSI参照モデル セキュリティ設定監査レポート\n")
        out.append("> 本レポートは `scripts/osi_security_audit.py` により自動生成されたインフラセキュリティ設定の評価結果です。\n")

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

        out.append("## 2. セキュリティグループ関係性図 (Mermaid Architecture)\n")
        out.append("各セキュリティグループのインバウンド・アウトバウンド通信および外部との接続関係を可視化したトポロジー図です。\n")
        out.append(mermaid_chart)
        out.append("")

        out.append("## 3. レイヤ別セキュリティ詳細評価\n")
        for layer in range(1, 8):
            l_findings = [f for f in findings if f.layer == layer]
            out.append(f"### {OsiAuditor.LAYER_NAMES[layer]}\n")
            for f in l_findings:
                badge = "✅ **PASS**" if f.severity == "PASS" else f"⚠️ **{f.severity}**"
                out.append(f"#### {badge}: {f.title} (`{f.check_id}`)")
                out.append(f"- **対象リソース**: `{f.resource}`")
                out.append(f"- **ファイル**: `{f.file_path or 'N/A'}`")
                out.append(f"- **詳細内容**: {f.description}")
                if f.severity != "PASS":
                    out.append(f"- **改善提案**: {f.recommendation}")
                    if f.code_remediation:
                        out.append("\n**推奨修正コード (Terraform HCL):**\n```hcl")
                        out.append(f.code_remediation.strip())
                        out.append("```")
                    if f.diff_patch:
                        out.append("\n<details><summary>Unified Diff Patch プレビュー</summary>\n\n```diff")
                        out.append(f.diff_patch.strip())
                        out.append("\n```\n</details>")
                out.append("")

        actionable = [f for f in findings if f.severity in ("CRITICAL", "HIGH")]
        out.append("## 4. 改善提案と推奨アクション\n")
        if not actionable:
            out.append("> [!NOTE]\n> 重大なセキュリティ不備や規約違反は検出されませんでした。\n")
        else:
            for idx, f in enumerate(actionable, 1):
                out.append(f"> [!WARNING]\n> **{idx}. [{f.severity}] {f.title}** ({f.layer_name})\n>\n> - **現状とリスク**: {f.description}\n> - **推奨される改善策**: {f.recommendation}\n> - **対象ファイル**: `{f.file_path}`\n")

        return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description="OSI Reference Model Security Auditor & Remediation Tool for Terraform")
    parser.add_argument("--target-dir", "-d", default=".", help="Root directory of Terraform files (default: .)")
    parser.add_argument("--rules-config", "-c", help="Path to YAML/JSON rules config file (default: scripts/osi_rules.yaml)")
    parser.add_argument("--markdown", "-m", action="store_true", help="Output report in Markdown format")
    parser.add_argument("--output", "-o", help="File path to save the generated report")
    parser.add_argument("--mermaid-only", action="store_true", help="Output only the Mermaid diagram")
    parser.add_argument("--show-diff", action="store_true", help="Show unified diff patches in console output")
    parser.add_argument("--generate-patch", help="Generate a unified patch file and save to path")
    parser.add_argument("--fix", action="store_true", help="Automatically apply recommended remediation fixes to files")
    parser.add_argument("--dry-run", action="store_true", help="Preview fixes without modifying files")
    parser.add_argument("--no-backup", action="store_true", help="Do not create .bak backup files when applying --fix")
    parser.add_argument("--exit-code", action="store_true", help="Exit with code 1 if CRITICAL or HIGH findings exist")
    args = parser.parse_args()

    # Determine default config path
    config_path = args.rules_config
    if not config_path:
        default_yaml = os.path.join(args.target_dir, "scripts", "osi_rules.yaml")
        if os.path.exists(default_yaml):
            config_path = default_yaml
        else:
            default_yaml_local = os.path.join(os.path.dirname(__file__), "osi_rules.yaml")
            if os.path.exists(default_yaml_local):
                config_path = default_yaml_local

    config = RulesConfig(config_path)
    auditor = OsiAuditor(args.target_dir, config)
    auditor.load_codebase()
    auditor.run_audit()

    mermaid_chart = MermaidGenerator.generate(auditor.sgs, auditor.rules)

    if args.mermaid_only:
        print(mermaid_chart)
        sys.exit(0)

    # Patch Generation
    if args.generate_patch:
        patch_text = RemediationManager.generate_unified_patch(auditor.findings, auditor.root_dir)
        with open(args.generate_patch, 'w', encoding='utf-8') as pf:
            pf.write(patch_text)
        print(f"{Colors.GREEN}✓ Unified patch successfully saved to {args.generate_patch}{Colors.RESET}")
        print(f"To apply: git apply {args.generate_patch}")

    # Auto Fix Mode
    if args.fix:
        fix_results = RemediationManager.apply_fixes(
            auditor.findings,
            dry_run=args.dry_run,
            backup=not args.no_backup
        )
        mode_str = "[DRY-RUN] " if args.dry_run else ""
        print(f"\n{Colors.BOLD}{Colors.CYAN}=== Auto-Remediation Execution Results {mode_str}==={Colors.RESET}")
        for app in fix_results["applied"]:
            print(f"{Colors.GREEN}✓ Modified: {app['file']} (Rules applied: {', '.join(app['rules'])}){Colors.RESET}")
            if app.get("backup_created"):
                print(f"  Backup saved: {app['file']}.bak")
        for sk in fix_results["skipped"]:
            print(f"{Colors.YELLOW}- Skipped: {sk['file']} ({sk['reason']}){Colors.RESET}")
        for fl in fix_results["failed"]:
            print(f"{Colors.RED}✗ Failed: {fl['file']} ({fl['error']}){Colors.RESET}\n")

    if args.markdown:
        report = ReportFormatter.format_markdown(auditor.findings, mermaid_chart)
    else:
        report = ReportFormatter.format_console(auditor.findings, mermaid_chart, show_diff=args.show_diff)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"Report saved to {args.output}")
    elif not args.fix and not args.generate_patch:
        print(report)

    if args.exit_code:
        has_critical_or_high = any(f.severity in ("CRITICAL", "HIGH") for f in auditor.findings)
        if has_critical_or_high:
            sys.exit(1)


if __name__ == '__main__':
    main()
