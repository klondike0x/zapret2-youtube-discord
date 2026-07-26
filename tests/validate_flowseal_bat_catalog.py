from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FAMILIES = [
    "general",
    "general (ALT)",
    *[f"general (ALT{i})" for i in range(2, 15)],
    "general (FAKE TLS AUTO)",
    "general (FAKE TLS AUTO ALT)",
    "general (FAKE TLS AUTO ALT2)",
    "general (FAKE TLS AUTO ALT3)",
    "general (SIMPLE FAKE)",
    "general (SIMPLE FAKE ALT)",
    "general (SIMPLE FAKE ALT2)",
    "general (SIMPLE FAKE ALT3)",
]


def profile_name(display_name: str) -> str:
    return display_name.lower().replace(" ", "-").replace("(", "").replace(")", "") + ".txt"


def main() -> int:
    errors: list[str] = []
    for display_name in FAMILIES:
        bat = ROOT / f"{display_name}.bat"
        profile = ROOT / "profiles" / profile_name(display_name)
        if not bat.is_file():
            errors.append(f"отсутствует {bat.name}")
            continue
        if not profile.is_file():
            errors.append(f"отсутствует profiles/{profile.name}")
            continue
        text = bat.read_text(encoding="utf-8-sig")
        expected = f'call "%~dp0launcher.bat" "profiles\\{profile.name}"'
        if expected not in text:
            errors.append(f"{bat.name}: не использует общий launcher и свой TXT-профиль")
        raw = profile.read_bytes()
        if b"\r\n" not in raw or raw.replace(b"\r\n", b"").find(b"\n") >= 0:
            errors.append(f"profiles/{profile.name}: требуется CRLF")
        for token in [b"--lua-init=@lua/zapret-lib.lua", b"--lua-init=@lua/zapret-antidpi.lua", b"--wf-"]:
            if token not in raw:
                errors.append(f"profiles/{profile.name}: отсутствует {token.decode()}")

    service = (ROOT / "service.bat").read_text(encoding="utf-8-sig")
    selector = (ROOT / "tools" / "list-profiles.bat").read_text(encoding="utf-8-sig")
    if "tools\\list-profiles.bat" not in service.lower() or "profiles\\general*.txt" not in selector.lower():
        errors.append("service.bat: каталог профилей должен формироваться динамически")

    if errors:
        print("FAIL flowseal BAT catalog:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"PASS Flowseal-style BAT catalog: {len(FAMILIES)} strategies")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
