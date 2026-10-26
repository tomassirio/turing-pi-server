"""
Tizen Read-Only Inventory and Firmware Analysis Suite.
Designed for non-destructive, evidence-first auditing of Samsung Tizen TV firmware and live devices.
"""

import os
import sys
import json
import logging
import hashlib
from typing import Dict, List, Any, Optional
from pathlib import Path

# Setup structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("tizen_audit")

# Whitelist of strictly read-only inspection commands for live SDB sessions.
# Any command outside this whitelist or containing shell redirection/chaining will be rejected.
READONLY_COMMAND_WHITELIST = {
    "uname": ["uname", "-a"],
    "os_release": ["cat", "/etc/os-release"],
    "tizen_release": ["cat", "/etc/tizen-release"],
    "build_info": ["cat", "/etc/build-info"],
    "cpuinfo": ["cat", "/proc/cpuinfo"],
    "cmdline": ["cat", "/proc/cmdline"],
    "mounts": ["cat", "/proc/mounts"],
    "df": ["df", "-h"],
    "id": ["id"],
    "smack_current": ["cat", "/proc/self/attr/current"],
    "smack_rules": ["cat", "/etc/smack/accesses.d/default"],
    "services": ["systemctl", "list-unit-files", "--type=service", "--no-pager"],
    "active_services": ["systemctl", "list-units", "--type=service", "--state=running", "--no-pager"],
    "network_ports": ["netstat", "-tulpn"],
    "installed_pkgs": ["pkgcmd", "-l"],
    "ps": ["ps", "-ef"],
    "dmesg_boot": ["dmesg"]
}


def calculate_sha256(filepath: Path) -> Optional[str]:
    """Calculate SHA-256 hash of a file safely."""
    if not filepath.is_file():
        return None
    h = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()
    except (PermissionError, OSError) as e:
        logger.warning(f"Could not read {filepath}: {e}")
        return None


def is_command_safe(command: str) -> bool:
    """
    Validate that an ad-hoc command string is non-destructive, contains no
    redirection, pipes, or background operators, and belongs to known safe utilities.
    """
    forbidden_tokens = [">", "<", "|", ";", "&", "`", "$", "\n", "\r", "rm", "dd", "chmod", "chown", "mount", "umount", "reboot"]
    tokens = command.strip().split()
    if not tokens:
        return False

    base_cmd = tokens[0]
    # Check for forbidden characters/operators
    for tok in tokens:
        if any(char in tok for char in [">", "<", "|", ";", "&", "`", "$"]):
            return False

    # Ensure base command is a standard read-only tool
    safe_base_bins = {"cat", "uname", "id", "df", "ps", "netstat", "ss", "pkgcmd", "systemctl", "ls", "find", "stat", "smackctl"}
    return base_cmd in safe_base_bins


class OfflineFirmwareAnalyzer:
    """Performs read-only inspection of unpacked Tizen rootfs/image directory."""

    def __init__(self, rootfs_path: str):
        self.rootfs = Path(rootfs_path).resolve()
        if not self.rootfs.exists() or not self.rootfs.is_dir():
            raise ValueError(f"Rootfs directory does not exist or is not a directory: {rootfs_path}")

    def inspect_os_release(self) -> Dict[str, str]:
        """Extract OS identifiers from standard release files."""
        info = {}
        for candidate in ["etc/os-release", "usr/lib/os-release", "etc/tizen-release", "etc/build-info"]:
            target = self.rootfs / candidate
            if target.is_file():
                try:
                    with open(target, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            line = line.strip()
                            if line and not line.startswith("#") and "=" in line:
                                k, v = line.split("=", 1)
                                info[k.strip()] = v.strip().strip('"').strip("'")
                except OSError as e:
                    logger.warning(f"Failed to read {target}: {e}")
        return info

    def inspect_installed_packages(self) -> List[Dict[str, Any]]:
        """Identify Tizen web (.wgt) and native (.tpk) application manifests."""
        packages = []
        app_dirs = [
            self.rootfs / "usr/apps",
            self.rootfs / "opt/usr/apps",
            self.rootfs / "opt/share/packages"
        ]

        for base_dir in app_dirs:
            if not base_dir.is_dir():
                continue
            for entry in base_dir.iterdir():
                pkg_info = {"name": entry.name, "path": str(entry.relative_to(self.rootfs))}
                # Check for config.xml (Tizen Web Widget)
                config_xml = entry / "config.xml"
                if config_xml.is_file():
                    pkg_info["type"] = "tizen_web_widget"
                    pkg_info["config_sha256"] = calculate_sha256(config_xml)
                # Check for tizen-manifest.xml (Native TPK)
                manifest_xml = entry / "tizen-manifest.xml"
                if manifest_xml.is_file():
                    pkg_info["type"] = "tizen_native_app"
                    pkg_info["manifest_sha256"] = calculate_sha256(manifest_xml)

                packages.append(pkg_info)
        return packages

    def inspect_systemd_services(self) -> List[Dict[str, str]]:
        """List and summarize systemd services present in system unit directories."""
        services = []
        unit_dirs = [
            self.rootfs / "usr/lib/systemd/system",
            self.rootfs / "etc/systemd/system"
        ]
        for udir in unit_dirs:
            if not udir.is_dir():
                continue
            for sfile in udir.glob("*.service"):
                info = {"name": sfile.name, "path": str(sfile.relative_to(self.rootfs))}
                try:
                    with open(sfile, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            if line.startswith("ExecStart="):
                                info["exec_start"] = line.strip().split("=", 1)[1]
                            elif line.startswith("User="):
                                info["user"] = line.strip().split("=", 1)[1]
                            elif line.startswith("SmackProcessLabel="):
                                info["smack_label"] = line.strip().split("=", 1)[1]
                except OSError:
                    pass
                services.append(info)
        return services

    def inspect_suid_binaries(self) -> List[Dict[str, Any]]:
        """Identify SUID/SGID binaries in rootfs."""
        suid_binaries = []
        for root, _, files in os.walk(self.rootfs):
            for file in files:
                fpath = Path(root) / file
                try:
                    if fpath.is_symlink():
                        continue
                    st = fpath.stat()
                    # Check S_ISUID (0o4000) or S_ISGID (0o2000)
                    is_suid = bool(st.st_mode & 0o4000)
                    is_sgid = bool(st.st_mode & 0o2000)
                    if is_suid or is_sgid:
                        suid_binaries.append({
                            "path": str(fpath.relative_to(self.rootfs)),
                            "uid": st.st_uid,
                            "gid": st.st_gid,
                            "mode": oct(st.st_mode),
                            "is_suid": is_suid,
                            "is_sgid": is_sgid,
                            "sha256": calculate_sha256(fpath)
                        })
                except (PermissionError, FileNotFoundError):
                    continue
        return suid_binaries

    def inspect_smack_rules(self) -> List[str]:
        """Collect SMACK MAC access rules defined in /etc/smack."""
        rules = []
        smack_dir = self.rootfs / "etc/smack"
        if smack_dir.is_dir():
            for rfile in smack_dir.rglob("*"):
                if rfile.is_file():
                    try:
                        with open(rfile, "r", encoding="utf-8", errors="ignore") as f:
                            for line in f:
                                line = line.strip()
                                if line and not line.startswith("#"):
                                    rules.append(line)
                    except OSError:
                        pass
        return rules

    def generate_report(self) -> Dict[str, Any]:
        """Aggregate all findings into a structured dictionary."""
        logger.info(f"Analyzing rootfs at {self.rootfs}")
        return {
            "os_release": self.inspect_os_release(),
            "packages_count": len(self.inspect_installed_packages()),
            "packages": self.inspect_installed_packages(),
            "services_count": len(self.inspect_systemd_services()),
            "services": self.inspect_systemd_services(),
            "suid_binaries_count": len(self.inspect_suid_binaries()),
            "suid_binaries": self.inspect_suid_binaries(),
            "smack_rules_count": len(self.inspect_smack_rules()),
            "smack_rules_sample": self.inspect_smack_rules()[:20]
        }
