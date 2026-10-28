"""
Unit tests for Tizen Read-Only Firmware Analyzer and Live Collector.
"""

import os
import unittest
import tempfile
from unittest.mock import patch, MagicMock
from pathlib import Path
from scripts.tizen_audit.analyzer import (
    is_command_safe,
    calculate_sha256,
    OfflineFirmwareAnalyzer,
    READONLY_COMMAND_WHITELIST
)
from scripts.tizen_audit.live_collector import LiveSDBCollector


class TestTizenAnalyzer(unittest.TestCase):

    def test_is_command_safe_whitelist(self):
        self.assertTrue(is_command_safe("cat /etc/os-release"))
        self.assertTrue(is_command_safe("uname -a"))
        self.assertTrue(is_command_safe("id"))
        self.assertTrue(is_command_safe("systemctl list-unit-files"))
        self.assertTrue(is_command_safe("pkgcmd -l"))

    def test_is_command_safe_rejects_dangerous(self):
        # Pipes and redirects
        self.assertFalse(is_command_safe("cat /etc/passwd > /tmp/out"))
        self.assertFalse(is_command_safe("uname -a | sh"))
        self.assertFalse(is_command_safe("id; rm -rf /"))
        self.assertFalse(is_command_safe("cat `whoami`"))
        self.assertFalse(is_command_safe("cat $(whoami)"))
        # Mutating commands
        self.assertFalse(is_command_safe("rm -rf /opt"))
        self.assertFalse(is_command_safe("chmod 777 /bin/sh"))
        self.assertFalse(is_command_safe("mount -o remount,rw /"))
        self.assertFalse(is_command_safe("reboot"))
        self.assertFalse(is_command_safe(""))

    def test_offline_firmware_analyzer_mock(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)

            # Create mock /etc/os-release
            etc = root / "etc"
            etc.mkdir(parents=True)
            os_release = etc / "os-release"
            os_release.write_text('NAME="Tizen"\nVERSION="6.0"\nPLATFORM="NikeM2"\n')

            # Create mock systemd service
            systemd = root / "usr/lib/systemd/system"
            systemd.mkdir(parents=True)
            service = systemd / "test-daemon.service"
            service.write_text("[Service]\nExecStart=/usr/bin/daemon\nUser=root\nSmackProcessLabel=System::Daemon\n")

            # Create mock package
            app_dir = root / "usr/apps/org.example.app"
            app_dir.mkdir(parents=True)
            manifest = app_dir / "tizen-manifest.xml"
            manifest.write_text("<manifest package='org.example.app' version='1.0.0'/>")

            # Create mock smack rules
            smack_dir = etc / "smack"
            smack_dir.mkdir(parents=True)
            smack_rule = smack_dir / "rules.txt"
            smack_rule.write_text("System::Daemon User::Home rw\n# comment\n")

            # Run analyzer
            analyzer = OfflineFirmwareAnalyzer(str(root))
            report = analyzer.generate_report()

            self.assertEqual(report["os_release"]["NAME"], "Tizen")
            self.assertEqual(report["os_release"]["VERSION"], "6.0")
            self.assertEqual(report["os_release"]["PLATFORM"], "NikeM2")

            self.assertEqual(report["services_count"], 1)
            self.assertEqual(report["services"][0]["name"], "test-daemon.service")
            self.assertEqual(report["services"][0]["smack_label"], "System::Daemon")

            self.assertEqual(report["packages_count"], 1)
            self.assertEqual(report["packages"][0]["name"], "org.example.app")
            self.assertEqual(report["packages"][0]["type"], "tizen_native_app")

            self.assertEqual(report["smack_rules_count"], 1)
            self.assertIn("System::Daemon User::Home rw", report["smack_rules_sample"])

    @patch("subprocess.run")
    def test_live_collector_safe_execution(self, mock_subproc):
        mock_subproc.return_value = MagicMock(returncode=0, stdout="Linux tizen 4.19", stderr="")
        collector = LiveSDBCollector(target_ip="192.168.1.100")

        # Whitelisted command
        res = collector.run_sdb_command(["uname", "-a"])
        self.assertEqual(res["status"], "success")
        self.assertIn("Linux tizen", res["stdout"])

        # Unsafe command rejected prior to execution
        res_unsafe = collector.run_sdb_command(["rm", "-rf", "/tmp"])
        self.assertEqual(res_unsafe["status"], "rejected")
        mock_subproc.assert_called_once()  # Only called for the safe command


if __name__ == "__main__":
    unittest.main()
