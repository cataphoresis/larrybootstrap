#!/usr/bin/env python3
"""Offline workstation regression checks; no sudo, installs, or host changes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WorkstationTests(unittest.TestCase):
    def test_firefox_merge_and_idempotency(self):
        with tempfile.TemporaryDirectory() as directory:
            policy = Path(directory) / "policies.json"
            original = {"policies": {"Homepage": {"URL": "https://example.org"},
                                     "ExtensionSettings": {"other@example.org": {"installation_mode": "allowed"}}}}
            policy.write_text(json.dumps(original))
            command = '''set -e
source common/firefox-policy.sh
sudo() { "$@"; }
apply_firefox_policy "$TEST_POLICY" common/profiles/firefox.json
'''
            env = {**os.environ, "TEST_POLICY": str(policy)}
            subprocess.run(["bash", "-c", command], cwd=ROOT, env=env, check=True)
            result = json.loads(policy.read_text())["policies"]
            self.assertEqual(result["Homepage"], original["policies"]["Homepage"])
            self.assertIn("other@example.org", result["ExtensionSettings"])
            intent = json.loads((ROOT / "common/profiles/firefox.json").read_text())
            self.assertEqual(len(intent["extensions"]), 5)
            for extension in intent["extensions"]:
                self.assertEqual(result["ExtensionSettings"][extension["id"]], {
                    "installation_mode": "force_installed", "install_url": extension["install_url"]})
            before = policy.stat().st_mtime_ns
            subprocess.run(["bash", "-c", command], cwd=ROOT, env=env, check=True)
            self.assertEqual(policy.stat().st_mtime_ns, before)
            policy.write_text("not valid json")
            failed = subprocess.run(["bash", "-c", command], cwd=ROOT, env=env, capture_output=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertEqual(policy.read_text(), "not valid json")

    def test_apfs_artifact_integrity(self):
        assets = ROOT / "platforms/linux/assets/apfs-fuse"
        for line in (assets / "SHA256SUMS").read_text().splitlines():
            digest, name = line.split()
            self.assertEqual(hashlib.sha256((assets / name).read_bytes()).hexdigest(), digest)
        self.assertTrue((assets / "LICENSE").is_file())
        self.assertTrue((assets / "LZFSE-LICENSE").is_file())

    def test_snap_install_control_flow(self):
        script = '''set -uo pipefail
source platforms/linux/modules/apps.sh
section() { :; }; success() { :; }; failure() { :; }
snap() { [[ "$1" == list && "$TEST_CASE" == present ]]; }
sudo() {
    printf '%s\\n' "$*" >> "$TEST_LOG"
    [[ "$TEST_CASE" != failure || "$1" != systemctl ]]
}
install_rpi_imager
'''
        with tempfile.TemporaryDirectory() as directory:
            for case in ("present", "missing", "failure"):
                log = Path(directory) / case
                env = {**os.environ, "TEST_CASE": case, "TEST_LOG": str(log)}
                result = subprocess.run(["bash", "-c", script], cwd=ROOT, env=env, capture_output=True)
                self.assertEqual(result.returncode == 0, case != "failure")
                self.assertEqual("snap install rpi-imager" in log.read_text(), case == "missing")

    def test_apt_core_and_profile_contract(self):
        output = subprocess.check_output(["bash", "-c", '''
source platforms/linux/modules/packages.sh
printf '%s\\n' "${CORE_PACKAGES[@]}"
'''], cwd=ROOT, text=True).splitlines()
        for package in ("git", "snapd", "samba", "smbclient", "gvfs-backends", "ffmpeg", "mousepad"):
            self.assertIn(package, output)
        for profile in ("minimal", "standard", "developer", "homelab"):
            output = subprocess.check_output(["bash", "-c", '''
source "platforms/macos/profiles/$1.conf"
printf '%s\\n' "${FORMULAE[@]}" "${CASKS[@]}" "${MANUAL_FORMULAE[@]}"
''', "bash", profile], cwd=ROOT, text=True).splitlines()
            self.assertIn("ffmpeg", output)
            self.assertIn("tailscale-app", output)
            for retired in ("handbrake-app", "makemkv", "mkvtoolnix", "yt-dlp", "rust", "tauri"):
                self.assertNotIn(retired, output)


if __name__ == "__main__":
    unittest.main()
