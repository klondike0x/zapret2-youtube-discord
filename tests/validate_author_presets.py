from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "bin" / "winws2.exe"
EXPECTED = ["Default v5.txt", "Ростелеком.txt"]


def main() -> int:
    for name in EXPECTED:
        profile = ROOT / "profiles" / name
        if not profile.is_file():
            print(f"FAIL: отсутствует пресет автора {name}", file=sys.stderr)
            return 1
        raw = profile.read_bytes()
        if b"\n" in raw.replace(b"\r\n", b""):
            print(f"FAIL: {name} не CRLF", file=sys.stderr)
            return 1
        temporary = ROOT / "profiles" / f"dry-{profile.stem.replace(' ', '-')}.txt"
        temporary.write_bytes(b"--dry-run\r\n" + raw)
        try:
            result = subprocess.run(
                [str(EXE), f"@profiles/{temporary.name}"], cwd=ROOT,
                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60,
            )
        finally:
            temporary.unlink(missing_ok=True)
        output = result.stdout + result.stderr
        if result.returncode != 0 or "command line parameters verified" not in output:
            print(f"FAIL {name}:\n{output}", file=sys.stderr)
            return 1
        print(f"PASS {name}: актуальный winws2 принял пресет автора")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
