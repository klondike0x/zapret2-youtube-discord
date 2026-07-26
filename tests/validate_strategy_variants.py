from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "bin" / "winws2.exe"

VARIANTS = {
    "general (SIMPLE FAKE).bat": (
        "general-simple-fake.txt",
        ["--lua-desync=fake:blob=tls_google:repeats=6:tcp_ts=-600000"],
    ),
    "general (MULTISPLIT).bat": (
        "general-multisplit.txt",
        ["--lua-desync=multisplit:pos=1:seqovl=681:seqovl_pattern=tls_google"],
    ),
    "general (FAKE MULTISPLIT).bat": (
        "general-fake-multisplit.txt",
        [
            "--lua-desync=fake:blob=tls_google:repeats=8:tcp_ts=-600000",
            "--lua-desync=multisplit:pos=1:seqovl=681:seqovl_pattern=tls_google",
        ],
    ),
    "general (HOSTFAKESPLIT).bat": (
        "general-hostfakesplit.txt",
        ["--lua-desync=hostfakesplit:host=www.google.com:repeats=4:tcp_ts=-600000"],
    ),
    "general (FAKE TLS AUTO).bat": (
        "general-fake-tls-auto.txt",
        [
            "--lua-desync=fake:blob=fake_default_tls:repeats=8:tcp_seq=10000000:tls_mod=rnd,dupsid,sni=www.google.com",
            "--lua-desync=multidisorder:pos=1,midsld",
        ],
    ),
}


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    service = (ROOT / "service.bat").read_text(encoding="utf-8-sig")
    readme = (ROOT / "README.md").read_text(encoding="utf-8-sig")

    for launcher_name, (profile_name, markers) in VARIANTS.items():
        launcher = ROOT / launcher_name
        profile = ROOT / "profiles" / profile_name
        if not launcher.is_file():
            return fail(f"нет BAT: {launcher_name}")
        if not profile.is_file():
            return fail(f"нет профиля: {profile_name}")

        launcher_text = launcher.read_text(encoding="utf-8-sig")
        if f"profiles\\{profile_name}" not in launcher_text:
            return fail(f"{launcher_name} не указывает на {profile_name}")
        if f"profiles\\{profile_name}" not in service:
            return fail(f"{profile_name} отсутствует в service.bat")
        if f"`{launcher_name}`" not in readme:
            return fail(f"{launcher_name} не описан в README")

        text = profile.read_text(encoding="utf-8-sig")
        for marker in markers:
            if marker not in text:
                return fail(f"{profile_name}: отсутствует {marker}")
        for line in text.splitlines():
            if ":tcp_ts" in line and ":tcp_ts=" not in line:
                return fail(f"{profile_name}: tcp_ts без значения")
        raw = profile.read_bytes()
        if b"\n" in raw.replace(b"\r\n", b""):
            return fail(f"{profile_name}: не CRLF")

        dry = ROOT / "profiles" / f"dry-{profile_name}"
        # Parser-only probe must not collide with a manually running profile.
        # Replace only global WinDivert capture lines in the temporary copy.
        dry_lines = []
        capture_added = False
        for source_line in raw.splitlines(keepends=True):
            stripped = source_line.strip()
            if stripped.startswith((b"--wf-tcp-", b"--wf-udp-", b"--wf-raw-")):
                if not capture_added:
                    dry_lines.append(b"--wf-tcp-out=9\r\n")
                    capture_added = True
                continue
            dry_lines.append(source_line)
        dry.write_bytes(b"--dry-run\r\n" + b"".join(dry_lines))
        try:
            result = subprocess.run(
                [str(EXE), f"@profiles/{dry.name}"],
                cwd=ROOT,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=60,
            )
        finally:
            dry.unlink(missing_ok=True)
        output = result.stdout + result.stderr
        if result.returncode != 0 or "command line parameters verified" not in output:
            return fail(f"parser {profile_name} ({result.returncode}):\n{output}")
        print(f"PASS {profile_name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
