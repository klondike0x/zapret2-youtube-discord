from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "profiles" / "general-alt.txt"
EXE = ROOT / "bin" / "winws2.exe"


def require(text: str, token: str) -> None:
    if token not in text:
        raise AssertionError(f"отсутствует: {token}")


def main() -> int:
    if not PROFILE.exists():
        print(f"FAIL: профиль не найден: {PROFILE}", file=sys.stderr)
        return 1

    text = PROFILE.read_text(encoding="utf-8-sig")
    required = [
        "--lua-init=@lua/zapret-lib.lua",
        "--lua-init=@lua/zapret-antidpi.lua",
        "--lua-init=@lua/zapret-auto.lua",
        "--blob=discord_udp:@bin/ACTIVE_DISCORD_UDP.bin",
        "--blob=game_udp:@bin/ACTIVE_GAME_UDP.bin",
        "--hostlist=lists/list-general.txt",
        "--hostlist=lists/list-general-user.txt",
        "--hostlist-exclude=lists/list-exclude.txt",
        "--hostlist-exclude=lists/list-exclude-user.txt",
        "--ipset-exclude=lists/ipset-exclude.txt",
        "--ipset-exclude=lists/ipset-exclude-user.txt",
        "--hostlist=lists/list-google.txt",
        "--filter-l7=discord,stun",
        "--lua-desync=fake:blob=discord_udp:repeats=6",
        "--lua-desync=fake:blob=tls_google:ip_id=zero:repeats=6:tcp_ts=-600000",
        "--lua-desync=fakedsplit:pattern=hex_00:ip_id=zero:repeats=6:tcp_ts=-600000",
        "--lua-desync=fake:blob=stun_pat:repeats=6:tcp_ts=-600000",
        "--lua-desync=fake:blob=tls_google:repeats=6:tcp_ts=-600000",
        "--lua-desync=fake:blob=http_max:repeats=6:tcp_ts=-600000",
        "--filter-tcp=12",
        "--filter-udp=12",
        "--lua-desync=fake:blob=game_udp:repeats=12:payload=all",
        "--out-range=-n3",
    ]
    launcher = ROOT / "general (ALT).bat"
    service = (ROOT / "service.bat").read_text(encoding="utf-8-sig")
    if not launcher.is_file() or "general-alt.txt" not in launcher.read_text(encoding="utf-8-sig"):
        print("FAIL: отсутствует пользовательский BAT launcher", file=sys.stderr)
        return 1
    if "profiles\\general-alt.txt" not in service:
        print("FAIL: профиль отсутствует в service.bat", file=sys.stderr)
        return 1

    launcher_text = (ROOT / "launcher.bat").read_text(encoding="utf-8-sig")
    run_profile_text = (ROOT / "tools" / "run-profile.ps1").read_text(encoding="utf-8-sig")
    launch_required = [
        'start "zapret2: %PROFILE_TITLE%" /min',
        'cd /d "%~dp0"',
        'cmd.exe /d /k call tools\\run-window.bat',
    ]
    run_window_text = (ROOT / "tools" / "run-window.bat").read_text(encoding="utf-8-sig")
    try:
        for token in launch_required:
            require(launcher_text, token)
        require(run_profile_text, "Copy-Item -LiteralPath $profile -Destination $activeProfile -Force")
        require(run_window_text, 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-window.ps1"')
        run_window_ps1 = (ROOT / "tools" / "run-window.ps1").read_text(encoding="utf-8-sig")
        require(run_window_ps1, '& $exe "@tools/preset-active.txt"')
        if '& $exe "@tools/preset-active.txt"' in run_profile_text:
            raise AssertionError("run-profile.ps1 всё ещё запускает winws2 синхронно")
    except AssertionError as exc:
        print(f"FAIL: запуск не соответствует стилю Zapret1: {exc}", file=sys.stderr)
        return 1
    try:
        for token in required:
            require(text, token)
        for line in text.splitlines():
            if "--lua-desync=" in line and ":tcp_ts" in line and ":tcp_ts=" not in line:
                raise AssertionError(f"tcp_ts без числового смещения: {line}")
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    for rel in [
        "bin/ACTIVE_DISCORD_UDP.bin",
        "bin/ACTIVE_GAME_UDP.bin",
        "lists/list-general-user.txt",
        "lists/list-exclude-user.txt",
        "lists/ipset-exclude-user.txt",
    ]:
        if not (ROOT / rel).is_file():
            print(f"FAIL: зависимость не найдена: {rel}", file=sys.stderr)
            return 1

    raw = PROFILE.read_bytes()
    if b"\r\n" not in raw or raw.replace(b"\r\n", b"").find(b"\n") != -1:
        print("FAIL: профиль должен использовать только CRLF", file=sys.stderr)
        return 1

    dry = ROOT / "profiles" / "dry-general-alt.txt"
    dry.write_bytes(b"--dry-run\r\n" + raw)
    try:
        result = subprocess.run(
            [str(EXE), f"@profiles/{dry.name}"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=120,
        )
    finally:
        dry.unlink(missing_ok=True)
    output = result.stdout + result.stderr
    if result.returncode != 0 or "command line parameters verified" not in output:
        print(f"FAIL parser ({result.returncode}):\n{output}", file=sys.stderr)
        return 1

    print("PASS general-alt.txt: порт Flowseal и parser dry-run подтверждены")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
