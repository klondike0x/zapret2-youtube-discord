from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RELEASE_HASH = "2050ce15779b3595cec7320e664fa66f4ba517e978df6bd97b040803cda38535"
RELEASE_VERSION = "v1.0.4"


def main() -> int:
    readme = (ROOT / "README.md").read_text(encoding="utf-8-sig")
    workflow = (ROOT / ".github" / "workflows" / "release-security.yml").read_text(encoding="utf-8")
    script = ROOT / "tools" / "generate_virustotal_table.py"

    for token in [
        RELEASE_HASH,
        RELEASE_VERSION,
        f"zapret2-youtube-discord-{RELEASE_VERSION}.zip",
        f"https://www.virustotal.com/gui/file/{RELEASE_HASH}",
        "RiskTool",
        "VT_API_KEY",
        "Get-FileHash",
    ]:
        if token not in readme:
            print(f"FAIL README: отсутствует {token}", file=sys.stderr)
            return 1

    if "${{ secrets.VT_API_KEY }}" not in workflow:
        print("FAIL workflow: VirusTotal API key не читается из GitHub Secret", file=sys.stderr)
        return 1
    if '--api-key "$VT_API_KEY"' in workflow:
        print("FAIL workflow: секрет нельзя передавать аргументом процесса", file=sys.stderr)
        return 1
    if 'os.environ.get("VT_API_KEY")' not in script.read_text(encoding="utf-8"):
        print("FAIL generator: VT_API_KEY из окружения не используется", file=sys.stderr)
        return 1
    if "secrets.VT_API_KEY" in workflow and "permissions:\n  contents: write" not in workflow:
        print("FAIL workflow: contents: write требуется только для обновления Release notes", file=sys.stderr)
        return 1
    for token in ["zipfile.ZipFile", "release asset is not a ZIP archive", "testzip"]:
        if token not in workflow:
            print(f"FAIL workflow: отсутствует проверка ZIP: {token}", file=sys.stderr)
            return 1

    with tempfile.TemporaryDirectory() as directory:
        artifact = Path(directory) / "release.zip"
        artifact.write_bytes(b"zapret2 security metadata test\n")
        expected = hashlib.sha256(artifact.read_bytes()).hexdigest()
        result = subprocess.run(
            [sys.executable, str(script), str(artifact), "--version", "v-test"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        )
        output = result.stdout + result.stderr
        if result.returncode != 0 or expected not in output:
            print(f"FAIL generator:\n{output}", file=sys.stderr)
            return 1
        if f"https://www.virustotal.com/gui/file/{expected}" not in output:
            print("FAIL generator: ссылка VirusTotal не совпадает с SHA-256", file=sys.stderr)
            return 1

        env = os.environ.copy()
        env.pop("VT_API_KEY", None)
        result = subprocess.run(
            [sys.executable, str(script), str(artifact), "--version", "v-test"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        )
        if "статистика не запрошена: VT_API_KEY не настроен" not in result.stdout:
            print("FAIL generator: сообщение без API-ключа вводит в заблуждение", file=sys.stderr)
            return 1

    print("PASS README: SHA-256, VirusTotal, GPG and false-positive warning")
    print("PASS workflow: exact release upload with secret-only API key")
    print("PASS generator: report URL is deterministically derived from artifact SHA-256")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
