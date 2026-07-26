from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "bin" / "winws2.exe"


def main() -> int:
    profiles = sorted((ROOT / "profiles").glob("*.txt"))
    if not profiles:
        print("FAIL: профили не найдены", file=sys.stderr)
        return 1

    for profile in profiles:
        # Config-парсер Cygwin чувствителен к пробелам в имени файла и CRLF.
        # Временная копия получает безопасное имя без пробелов.
        safe_stem = "".join(ch if ch.isalnum() or ch in "-_" else "-" for ch in profile.stem)
        dry_profile = ROOT / "profiles" / f"dry-{safe_stem}.txt"
        raw = profile.read_bytes()
        dry_profile.write_bytes(b"--dry-run\r\n" + raw)
        result = subprocess.run(
            [str(EXE), f"@profiles/{dry_profile.name}"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        )
        dry_profile.unlink(missing_ok=True)
        output = (result.stdout + result.stderr).strip()
        if result.returncode != 0 or "parameters verified" not in output:
            print(f"FAIL {profile.name} (код {result.returncode})\n{output}", file=sys.stderr)
            return 1
        print(f"PASS {profile.name}: параметры подтверждены winws2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
