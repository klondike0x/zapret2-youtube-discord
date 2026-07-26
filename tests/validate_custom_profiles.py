from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "bin" / "winws2.exe"
CUSTOM = ["general.txt", "youtube.txt", "discord.txt"]


def main() -> int:
    for name in CUSTOM:
        path = ROOT / "profiles" / name
        text = path.read_text(encoding="utf-8-sig")
        required = [
            "--lua-init=@lua/zapret-lib.lua",
            "--lua-init=@lua/zapret-antidpi.lua",
            "--lua-init=@lua/zapret-auto.lua",
            "--lua-init=@lua/custom_funcs.lua",
            "--blob=tls_google:@bin/tls_clienthello_www_google_com.bin",
        ]
        for token in required:
            if token not in text:
                print(f"FAIL {name}: отсутствует базовый компонент рабочей архитектуры {token}", file=sys.stderr)
                return 1
        if "--hostlist=lists/youtube.txt" not in text and name != "discord.txt":
            print(f"FAIL {name}: нет полного списка YouTube автора", file=sys.stderr)
            return 1
        if "--ipset=lists/ipset-youtube.txt" not in text and name != "discord.txt":
            print(f"FAIL {name}: нет IP-фильтра YouTube", file=sys.stderr)
            return 1

        safe = ROOT / "profiles" / f"dry-custom-{path.stem}.txt"
        safe.write_bytes(b"--dry-run\r\n" + path.read_bytes())
        try:
            result = subprocess.run(
                [str(EXE), f"@profiles/{safe.name}"], cwd=ROOT,
                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120,
            )
        finally:
            safe.unlink(missing_ok=True)
        output = result.stdout + result.stderr
        if result.returncode != 0 or "command line parameters verified" not in output:
            print(f"FAIL {name}:\n{output}", file=sys.stderr)
            return 1
        print(f"PASS {name}: рабочая архитектура + актуальный winws2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
