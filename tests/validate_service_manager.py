from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "service.bat"
PREPARE = ROOT / "tools" / "prepare-service-profile.ps1"


def fail(message: str) -> None:
    raise AssertionError(message)


def require(text: str, token: str, label: str) -> None:
    if token.lower() not in text.lower():
        fail(f"{label}: отсутствует {token}")


def main() -> int:
    service = SERVICE.read_text(encoding="utf-8-sig")

    for token in [
        'set "SERVICE=winws2"',
        'set "LEGACY_SERVICE=zapret2-youtube-discord"',
        'set "SERVICE_DISPLAY=zapret2 YouTube Discord"',
        "prepare-service-profile.ps1",
        "service-next.txt",
        "service-active.txt",
        "sc create",
        "sc start",
        "sc stop",
        "sc delete",
        'set "SERVICE_BIN=\\\"%~dp0bin\\winws2.exe\\\" @\\\"%~dp0tools\\service-active.txt\\\""',
        "Service was created but failed to start",
        "Refusing to replace a winws2 service owned by another installation",
        "call :remove_legacy_quiet",
    ]:
        require(service, token, "service.bat")

    if 'set "SERVICE=zapret2-youtube-discord"' in service:
        fail("SCM имя должно совпадать с SERVICE_NAME=winws2 внутри бинарника")
    if re.search(r'sc create[^\r\n]+powershell\.exe', service, re.I):
        fail("SCM должен запускать winws2.exe напрямую, а не powershell.exe")
    if re.search(r"taskkill\s+/IM\s+winws2\.exe", service, re.I):
        fail("service.bat не должен завершать все процессы winws2.exe по имени")
    if 'reg query "HKLM\\System\\CurrentControlSet\\Services\\%SERVICE%" /v ImagePath' not in service:
        fail("service.bat не проверяет владельца существующей службы winws2")
    if "%SystemRoot%\\System32\\findstr.exe" not in service:
        fail("service.bat должен явно использовать Windows findstr.exe, а не внешний find из PATH")
    if re.search(r"\|\s*find(?:\.exe)?\s+/I", service, re.I):
        fail("service.bat зависит от неоднозначного find из PATH")

    if not PREPARE.is_file():
        fail("отсутствует tools/prepare-service-profile.ps1")
    prepare = PREPARE.read_text(encoding="utf-8-sig")
    for token in ["--chdir=", "WriteAllText", "ProfilePath", "service-active.txt"]:
        require(prepare, token, "prepare-service-profile.ps1")

    output = ROOT / "tools" / "service-test-contract.txt"
    probe = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(PREPARE),
            "-ProfilePath",
            str(ROOT / "profiles" / "general.txt"),
            "-OutputPath",
            str(output),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
    )
    try:
        if probe.returncode != 0 or not output.is_file():
            fail(f"подготовка service profile завершилась ошибкой: {(probe.stdout + probe.stderr).strip()}")
        data = output.read_bytes()
        source = (ROOT / "profiles" / "general.txt").read_bytes()
        if not data.startswith(b"--chdir=") or not data.endswith(source):
            fail("runtime profile не содержит абсолютный --chdir и исходный профиль")
        if b"\n" in data.replace(b"\r\n", b""):
            fail("runtime profile содержит LF вместо CRLF")
    finally:
        output.unlink(missing_ok=True)

    print("PASS winws2 SCM service manager contract")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
