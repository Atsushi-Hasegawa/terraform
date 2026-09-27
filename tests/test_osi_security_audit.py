"""
Unit tests for OSI Reference Model Security Auditor & Auto-Remediation Tool
"""

import os
import sys
import tempfile
import pytest

# Ensure scripts directory is in sys.path
SCRIPT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scripts"))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from osi_security_audit import (
    HclParser,
    HclResource,
    Finding,
    RulesConfig,
    OsiAuditor,
    RemediationManager,
    MermaidGenerator,
    ReportFormatter,
)


class TestHclParser:
    def test_clean_content(self):
        text = """
        # Line comment 1
        // Line comment 2
        /* Block comment */
        resource "aws_vpc" "main" {
            cidr_block = "10.0.0.0/16" # inline comment
        }
        """
        cleaned = HclParser.clean_content(text)
        assert "# Line comment 1" not in cleaned
        assert "// Line comment 2" not in cleaned
        assert "Block comment" not in cleaned
        assert 'cidr_block = "10.0.0.0/16"' in cleaned

    def test_parse_blocks(self):
        with tempfile.NamedTemporaryFile("w", suffix=".tf", delete=False) as f:
            f.write("""
            resource "aws_vpc" "test_vpc" {
                cidr_block = "10.0.0.0/16"
                enable_dns_support = true
            }

            resource "aws_subnet" "test_subnet" {
                vpc_id = aws_vpc.test_vpc.id
                cidr_block = "10.0.1.0/24"
            }
            """)
            f_path = f.name

        try:
            resources = HclParser.parse_blocks(f_path)
            assert len(resources) == 2
            assert resources[0].type == "aws_vpc"
            assert resources[0].name == "test_vpc"
            assert resources[0].attrs.get("cidr_block") == "10.0.0.0/16"
            assert resources[1].type == "aws_subnet"
            assert resources[1].name == "test_subnet"
        finally:
            os.remove(f_path)


class TestRulesConfig:
    def test_default_config(self):
        config = RulesConfig()
        assert config.is_enabled("L1-REGION-POLICY") is True
        assert config.get_severity("L1-REGION-POLICY", "DEFAULT") == "DEFAULT"
        assert config.is_suppressed("L1-REGION-POLICY", "res") is False
        assert "ap-northeast-1" in config.get_setting("allowed_regions")

    def test_custom_overrides(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            f.write("""
            {
                "rules": {
                    "L1-REGION-POLICY": {
                        "enabled": false,
                        "severity": "LOW"
                    }
                },
                "suppressions": [
                    {
                        "check_id": "L3-NETWORK-ACL",
                        "resource": "aws_network_acl.ignored"
                    }
                ]
            }
            """)
            cfg_path = f.name

        try:
            config = RulesConfig(cfg_path)
            assert config.is_enabled("L1-REGION-POLICY") is False
            assert config.get_severity("L1-REGION-POLICY", "HIGH") == "LOW"
            assert config.is_suppressed("L3-NETWORK-ACL", "aws_network_acl.ignored") is True
            assert config.is_suppressed("L3-NETWORK-ACL", "aws_network_acl.other") is False
        finally:
            os.remove(cfg_path)


class TestOsiAuditorLayers:
    @pytest.fixture
    def temp_workspace(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            yield tmpdir

    def test_l1_region_violation_and_remediation(self, temp_workspace):
        tf_file = os.path.join(temp_workspace, "main.tf")
        with open(tf_file, "w") as f:
            f.write("""
            resource "aws_s3_bucket" "b" {
                region = "us-east-1"
            }
            """)
        auditor = OsiAuditor(temp_workspace)
        auditor.load_codebase()
        auditor.run_audit()

        findings = [f for f in auditor.findings if f.check_id == "L1-REGION-POLICY"]
        assert len(findings) == 1
        assert findings[0].severity == "HIGH"
        assert findings[0].code_remediation is not None
        assert 'region = "ap-northeast-1"' in findings[0].code_remediation

    def test_l2_vpc_isolation(self, temp_workspace):
        tf_file = os.path.join(temp_workspace, "main.tf")
        with open(tf_file, "w") as f:
            f.write("""
            resource "aws_instance" "ec2" {
                ami = "ami-123456"
            }
            """)
        auditor = OsiAuditor(temp_workspace)
        auditor.load_codebase()
        auditor.run_audit()

        findings = [f for f in auditor.findings if f.check_id == "L2-VPC-ISOLATION"]
        assert len(findings) == 1
        assert findings[0].severity == "CRITICAL"
        assert 'resource "aws_vpc"' in findings[0].code_remediation

    def test_l3_subnet_segregation(self, temp_workspace):
        tf_file = os.path.join(temp_workspace, "vpc.tf")
        with open(tf_file, "w") as f:
            f.write("""
            resource "aws_vpc" "vpc-main" {
                cidr_block = "10.0.0.0/16"
            }
            resource "aws_subnet" "public_subnet" {
                vpc_id = aws_vpc.vpc-main.id
                cidr_block = "10.0.1.0/24"
            }
            """)
        auditor = OsiAuditor(temp_workspace)
        auditor.load_codebase()
        auditor.run_audit()

        l3_findings = [f for f in auditor.findings if f.check_id == "L3-SUBNET-SEGREGATION"]
        assert len(l3_findings) == 1
        assert l3_findings[0].severity == "HIGH"
        assert 'resource "aws_subnet" "private_subnet"' in l3_findings[0].code_remediation
        assert l3_findings[0].diff_patch is not None

    def test_l4_dangerous_management_ports(self, temp_workspace):
        tf_file = os.path.join(temp_workspace, "sg.tf")
        with open(tf_file, "w") as f:
            f.write("""
            resource "aws_security_group" "ssh_sg" {
                name = "ssh-sg"
            }
            resource "aws_vpc_security_group_ingress_rule" "open_ssh" {
                security_group_id = aws_security_group.ssh_sg.id
                cidr_ipv4 = "0.0.0.0/0"
                from_port = 22
                to_port = 22
                ip_protocol = "tcp"
            }
            """)
        auditor = OsiAuditor(temp_workspace)
        auditor.load_codebase()
        auditor.run_audit()

        findings = [f for f in auditor.findings if f.check_id == "L4-MANAGEMENT-PORTS"]
        assert len(findings) == 1
        assert findings[0].severity == "CRITICAL"

    def test_l7_waf_and_imdsv2(self, temp_workspace):
        tf_file = os.path.join(temp_workspace, "app.tf")
        with open(tf_file, "w") as f:
            f.write("""
            resource "aws_lb" "alb" {
                load_balancer_type = "application"
                drop_invalid_header_fields = true
            }
            resource "aws_instance" "ec2" {
                ami = "ami-123"
            }
            """)
        auditor = OsiAuditor(temp_workspace)
        auditor.load_codebase()
        auditor.run_audit()

        waf_findings = [f for f in auditor.findings if f.check_id == "L7-WAF-PROTECTION"]
        assert len(waf_findings) == 1
        assert waf_findings[0].severity == "HIGH"
        assert 'resource "aws_wafv2_web_acl"' in waf_findings[0].code_remediation

        imdsv2_findings = [f for f in auditor.findings if f.check_id == "L7-IMDSV2-PROTECTION"]
        assert len(imdsv2_findings) == 1
        assert imdsv2_findings[0].severity == "CRITICAL"
        assert 'http_tokens' in imdsv2_findings[0].code_remediation
        assert 'required' in imdsv2_findings[0].code_remediation


class TestRemediationManager:
    def test_generate_unified_patch(self):
        with tempfile.NamedTemporaryFile("w", suffix=".tf", delete=False) as f:
            f.write('resource "aws_vpc" "main" {\n  cidr_block = "10.0.0.0/16"\n}\n')
            f_path = f.name

        try:
            finding = Finding(
                layer=3,
                layer_name="L3 ネットワーク層 (Network Layer)",
                check_id="L3-SUBNET-SEGREGATION",
                severity="HIGH",
                title="パブリック / プライベートサブネットの未分離",
                resource="aws_subnet",
                file_path=f_path,
                description="desc",
                recommendation="rec",
                code_remediation='resource "aws_subnet" "private" {\n  cidr_block = "10.0.2.0/24"\n}\n'
            )
            patch = RemediationManager.generate_unified_patch([finding], os.path.dirname(f_path))
            assert "--- a/" in patch
            assert "+++ b/" in patch
            assert '+resource "aws_subnet" "private"' in patch
        finally:
            os.remove(f_path)

    def test_apply_fixes_dry_run_and_execution(self):
        with tempfile.NamedTemporaryFile("w", suffix=".tf", delete=False) as f:
            f.write('resource "aws_vpc" "main" {\n  cidr_block = "10.0.0.0/16"\n}\n')
            f_path = f.name

        try:
            finding = Finding(
                layer=3,
                layer_name="L3 ネットワーク層 (Network Layer)",
                check_id="L3-SUBNET-SEGREGATION",
                severity="HIGH",
                title="Subnet segregation",
                resource="aws_subnet",
                file_path=f_path,
                description="desc",
                recommendation="rec",
                code_remediation='resource "aws_subnet" "private_subnet" {\n  cidr_block = "10.0.2.0/24"\n}\n'
            )

            # Dry-run
            dry_results = RemediationManager.apply_fixes([finding], dry_run=True, backup=True)
            assert len(dry_results["applied"]) == 1
            assert os.path.exists(f_path + ".bak") is False
            with open(f_path, "r") as f:
                assert "private_subnet" not in f.read()

            # Real execution
            real_results = RemediationManager.apply_fixes([finding], dry_run=False, backup=True)
            assert len(real_results["applied"]) == 1
            assert os.path.exists(f_path + ".bak") is True
            with open(f_path, "r") as f:
                assert "private_subnet" in f.read()

            os.remove(f_path + ".bak")
        finally:
            os.remove(f_path)


class TestMermaidGenerator:
    def test_mermaid_generation(self):
        sg_res = HclResource(
            kind="resource",
            type="aws_security_group",
            name="alb_sg",
            attrs={"description": "ALB SG"},
            raw_body="",
            file_path="elb.tf"
        )
        rule_res = HclResource(
            kind="resource",
            type="aws_vpc_security_group_ingress_rule",
            name="allow_https",
            attrs={
                "security_group_id": "aws_security_group.alb_sg.id",
                "cidr_ipv4": "0.0.0.0/0",
                "from_port": "443",
                "to_port": "443",
                "ip_protocol": "tcp"
            },
            raw_body="",
            file_path="elb.tf"
        )

        chart = MermaidGenerator.generate({"alb_sg": sg_res}, [rule_res])
        assert "graph TB" in chart
        assert "subgraph External" in chart
        assert "Internet -->|\"TCP:443\"| sg_alb_sg" in chart
