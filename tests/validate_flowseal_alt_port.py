from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "profiles" / "general-alt.txt"
EXE = ROOT / "bin" / "winws2.exe"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    if not PROFILE.is_file():
        return fail("профиль general-alt.txt не найден")

    launcher = ROOT / "general (ALT).bat"
    if not launcher.is_file() or "profiles\\general-alt.txt" not in launcher.read_text(encoding="utf-8-sig"):
        return fail("general (ALT).bat не указывает на general-alt.txt")

    service = (ROOT / "service.bat").read_text(encoding="utf-8-sig")
    selector = (ROOT / "tools" / "list-profiles.bat").read_text(encoding="utf-8-sig")
    if "tools\\list-profiles.bat" not in service or "profiles\\general*.txt" not in selector:
        return fail("general-alt.txt не охвачен динамическим меню службы")

    text = PROFILE.read_text(encoding="utf-8-sig")
    required = [
        "--lua-init=@lua/zapret-lib.lua",
        "--lua-init=@lua/zapret-antidpi.lua",
        "--lua-init=@lua/zapret-auto.lua",
        "--lua-init=@lua/zapret-multishake.lua",
        "--hostlist=lists/list-general.txt",
        "--hostlist=lists/list-general-user.txt",
        "--hostlist=lists/list-google.txt",
        "--filter-l7=discord,stun",
        "--lua-desync=fake:blob=quic_vk:repeats=6:payload=quic_initial",
        "--lua-desync=fakedsplit:pattern=0x00:repeats=6:tcp_ts_up",
        "--filter-tcp=12",
        "--filter-udp=12",
    ]
    for token in required:
        if token not in text:
            return fail(f"general-alt.txt: отсутствует {token}")
    for line in text.splitlines():
        if ":tcp_ts" in line and ":tcp_ts=" not in line and ":tcp_ts_up" not in line:
            return fail(f"tcp_ts без значения: {line}")

    raw = PROFILE.read_bytes()
    if b"\r\n" not in raw or b"\n" in raw.replace(b"\r\n", b""):
        return fail("general-alt.txt должен использовать CRLF")

    dry = ROOT / "profiles" / "dry-general-alt.txt"
    dry.write_bytes(b"--dry-run\r\n" + raw)
    try:
        result = subprocess.run(
            [str(EXE), f"@profiles/{dry.name}"], cwd=ROOT,
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120,
        )
    finally:
        dry.unlink(missing_ok=True)
    output = result.stdout + result.stderr
    if result.returncode != 0 or "command line parameters verified" not in output:
        return fail(f"parser ({result.returncode}):\n{output}")

    print("PASS general-alt.txt: Player1545 strategy port and parser dry-run")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
