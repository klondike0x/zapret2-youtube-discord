from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "bin/winws2.exe",
    "bin/cygwin1.dll",
    "bin/WinDivert.dll",
    "bin/WinDivert64.sys",
    "lua/zapret-lib.lua",
    "lua/zapret-antidpi.lua",
    "files/list-general.txt",
    "files/list-youtube.txt",
    "files/list-discord.txt",
    "general.bat",
    "general (ALT).bat",
    "general (YouTube).bat",
    "general (Discord).bat",
    "general (SIMPLE FAKE).bat",
    "general (MULTISPLIT).bat",
    "general (FAKE MULTISPLIT).bat",
    "general (HOSTFAKESPLIT).bat",
    "general (FAKE TLS AUTO).bat",
    "service.bat",
]


def fail(message: str) -> None:
    raise AssertionError(message)


def validate_files() -> None:
    missing = [item for item in REQUIRED if not (ROOT / item).is_file()]
    if missing:
        fail("Отсутствуют обязательные файлы: " + ", ".join(missing))
    for obsolete in ["general (ALT Flowseal).bat", "profiles/general-alt-flowseal.txt"]:
        if (ROOT / obsolete).exists():
            fail(f"Остался устаревший дубликат: {obsolete}")


def validate_launchers() -> None:
    for name in [
        "general.bat", "general (ALT).bat", "general (YouTube).bat", "general (Discord).bat",
        "general (SIMPLE FAKE).bat", "general (MULTISPLIT).bat",
        "general (FAKE MULTISPLIT).bat", "general (HOSTFAKESPLIT).bat",
        "general (FAKE TLS AUTO).bat",
    ]:
        text = (ROOT / name).read_text(encoding="utf-8-sig")
        if "launcher.bat" not in text:
            fail(f"{name} не использует общий Zapret2 launcher")
        if re.search(r"(?<!2)winws\.exe", text, re.I):
            fail(f"{name} ссылается на старый winws.exe")

    launcher = (ROOT / "launcher.bat").read_text(encoding="utf-8-sig")
    runner = (ROOT / "tools" / "run-profile.ps1").read_text(encoding="utf-8-sig")
    window_runner = (ROOT / "tools" / "run-window.bat").read_text(encoding="utf-8-sig")
    window_runner_ps1 = (ROOT / "tools" / "run-window.ps1").read_text(encoding="utf-8-sig")
    if "preset-active.txt" not in runner or "Copy-Item" not in runner:
        fail("run-profile.ps1 не копирует выбранный пресет в безопасное имя без пробелов")
    if '& $exe "@tools/preset-active.txt"' in runner:
        fail("run-profile.ps1 не должен удерживать winws2 внутри PowerShell")
    if "winws2.exe" not in launcher:
        fail("launcher.bat не запускает winws2.exe")
    if 'cd /d "%~dp0"' not in launcher:
        fail("launcher.bat не сохраняет корень bundle как рабочий каталог")
    if not re.search(r'^start\s+"zapret2: %PROFILE_TITLE%"\s+/min\s+cmd\.exe\s+/d\s+/k\s+call\s+tools\\run-window\.bat', launcher, re.I | re.M):
        fail("launcher.bat не запускает отдельное минимизированное CMD-окно в стиле Zapret1")
    if 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-window.ps1"' not in window_runner:
        fail("run-window.bat не использует PowerShell-мост для Cygwin @config")
    if '& $exe "@tools/preset-active.txt"' not in window_runner_ps1:
        fail("run-window.ps1 не запускает winws2 с безопасным runtime-профилем")
    if "powershell.exe -NoProfile" not in launcher:
        fail("launcher.bat не использует PowerShell для подготовки безопасного @config")
    if "-ProfilePath \"%PROFILE%\"" not in launcher:
        fail("launcher.bat не передаёт абсолютный путь профиля безопасному подготовителю")
    if "if errorlevel 1" not in launcher or "pause" not in launcher:
        fail("launcher.bat не сообщает об ошибках подготовки или запуска")

    for profile in (ROOT / "profiles").glob("*.txt"):
        raw = profile.read_bytes()
        if b"\n" in raw.replace(b"\r\n", b""):
            fail(f"{profile.name} использует LF вместо обязательных для config-парсера CRLF")
        text = raw.decode("utf-8-sig")
        if "--lua-init" not in text or "--lua-desync" not in text:
            fail(f"{profile.name} не содержит стратегию Zapret2/Lua")


def validate_service() -> None:
    text = (ROOT / "service.bat").read_text(encoding="utf-8-sig")
    for token in [
        "winws2.exe",
        "PROFILE_PATH",
        "service-control.ps1",
        "stop-manual-winws2.ps1",
    ]:
        if token.lower() not in text.lower():
            fail(f"service.bat: отсутствует {token}")
    if "@$PROFILE" in text:
        fail("service.bat содержит литерал $PROFILE вместо BAT-переменной")
    if re.search(r"taskkill\s+/IM\s+winws\.exe", text, re.I):
        fail("service.bat управляет старым winws.exe")
    if re.search(r"taskkill\s+/IM\s+winws2\.exe", text, re.I):
        fail("service.bat не должен завершать все процессы winws2.exe")
    create_lines = [line.lower() for line in text.splitlines() if "sc create" in line.lower()]
    if any("powershell.exe" in line for line in create_lines):
        fail("SCM должен запускать winws2.exe напрямую")


def validate_binary() -> None:
    result = subprocess.run(
        [str(ROOT / "bin" / "winws2.exe"), "--version"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=15,
    )
    output = result.stdout + result.stderr
    if result.returncode != 0 or "lua_compat_ver" not in output:
        fail("bin/winws2.exe не подтверждён как Zapret2: " + output.strip())


def main() -> int:
    checks = [validate_files, validate_launchers, validate_service, validate_binary]
    for check in checks:
        check()
        print(f"PASS {check.__name__}")
    print("Проект прошёл статическую проверку Zapret2.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, subprocess.SubprocessError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
