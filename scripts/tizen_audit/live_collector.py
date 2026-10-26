"""
Live SDB Read-Only Information Collector.
Interacts with a Tizen device over SDB (Smart Development Bridge) using strictly read-only commands.
"""

import subprocess
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Any
from scripts.tizen_audit.analyzer import READONLY_COMMAND_WHITELIST, is_command_safe

logger = logging.getLogger("tizen_audit_live")


class LiveSDBCollector:
    """Connects to a Samsung Tizen TV via SDB and gathers read-only forensic artifacts."""

    def __init__(self, sdb_bin: str = "sdb", target_ip: str = ""):
        self.sdb_bin = sdb_bin
        self.target_ip = target_ip
        self.log_dir = Path("audit_logs")
        self.log_dir.mkdir(parents=True, exist_ok=True)

    def run_sdb_command(self, cmd_args: list) -> Dict[str, Any]:
        """Execute a whitelisted command via SDB shell."""
        full_cmd = [self.sdb_bin]
        if self.target_ip:
            full_cmd.extend(["-s", f"{self.target_ip}:26101"])
        full_cmd.extend(["shell"] + cmd_args)

        joined_str = " ".join(cmd_args)
        if not is_command_safe(joined_str):
            logger.error(f"Command '{joined_str}' rejected by safety filter.")
            return {"status": "rejected", "error": "Safety violation"}

        logger.info(f"Executing read-only command: {joined_str}")
        try:
            res = subprocess.run(
                full_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=15
            )
            return {
                "status": "success" if res.returncode == 0 else "error",
                "returncode": res.returncode,
                "stdout": res.stdout,
                "stderr": res.stderr
            }
        except FileNotFoundError:
            return {"status": "error", "error": f"SDB binary '{self.sdb_bin}' not found on host."}
        except subprocess.TimeoutExpired:
            return {"status": "timeout", "error": "Command timed out after 15s"}

    def collect_all(self) -> Dict[str, Any]:
        """Run all predefined read-only audit commands and log artifacts."""
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        report = {
            "timestamp": timestamp,
            "target": self.target_ip or "default",
            "results": {}
        }

        for name, cmd in READONLY_COMMAND_WHITELIST.items():
            report["results"][name] = self.run_sdb_command(cmd)

        log_file = self.log_dir / f"sdb_inventory_{timestamp}.json"
        with open(log_file, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        logger.info(f"Audit log saved to {log_file}")
        return report
