from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise AssertionError(message)


def require(text: str, token: str, label: str) -> None:
    if token.lower() not in text.lower():
        fail(f"{label}: отсутствует {token}")


def main() -> int:
    service = (ROOT / "service.bat").read_text(encoding="utf-8-sig")
    strategy_test_path = ROOT / "tools" / "test-strategies.ps1"
    prepare_path = ROOT / "tools" / "prepare-service-profile.ps1"

    for token in [
        "ZAPRET2 SERVICE MANAGER",
        "Install Service",
        "Remove Service",
        "Start Service",
        "Stop Service",
        "Check Status",
        "Run Diagnostics",
        "Run Strategy Tests",
        "tools\\list-profiles.bat",
        "prepare-service-profile.ps1",
        "test-strategies.ps1",
        "sc create",
        "sc start",
        "sc stop",
        "sc delete",
        "Runtime profile was preserved",
        "service-next.txt",
        "if errorlevel 1 exit /b 1",
        "winws2.exe",
        "stop-manual-winws2.ps1",
        "Profile",
        'set "SERVICE=winws2"',
    ]:
        require(service, token, "service.bat")

    if re.search(r"(?<!2)winws\.exe", service, re.I):
        fail("service.bat ссылается на движок Zapret1 winws.exe")
    if "startup shortcut" in service.lower():
        fail("service.bat подменяет настоящую службу ярлыком автозагрузки")
    if "powershell.exe\\\" -NoProfile" in service and "sc create" in service:
        fail("служба не должна регистрировать PowerShell вместо winws2.exe")

    if not strategy_test_path.is_file():
        fail("отсутствует tools/test-strategies.ps1")
    strategy_test = strategy_test_path.read_text(encoding="utf-8-sig")
    for token in [
        "Get-ChildItem",
        "general*.txt",
        "--dry-run",
        "parameters verified",
        "curl.exe",
        "TLS1.2",
        "TLS1.3",
        "Highest transport-check score",
        "test results",
        "Stop-Process",
        "SelfTest",
    ]:
        require(strategy_test, token, "tools/test-strategies.ps1")
    if "general*.bat" in strategy_test:
        fail("тест должен запускать Zapret2 TXT-профили напрямую, а не парсить BAT")
    if re.search(r"Get-Process\s+-Name\s+['\"]winws2['\"].*Stop-Process", strategy_test, re.I):
        fail("тест не должен завершать все пользовательские процессы winws2.exe")
    for token in ["Get-CimInstance Win32_Process", "Close manual winws2.exe before testing", "Stop-TestEngine -Process"]:
        require(strategy_test, token, "tools/test-strategies.ps1")
    for token in ["foreach ($attempt in 1..10)", "copy of winws2 is already running", "Get-Service -Name 'winws2'"]:
        require(strategy_test, token, "tools/test-strategies.ps1")
    for forbidden in ["--wf-tcp-out=81", "--wf-udp-out=444", "outbound and false", "Best strategy"]:
        if forbidden in strategy_test:
            fail(f"strategy test must not contain misleading isolation/ranking token: {forbidden}")
    running_guards = [match.start() for match in re.finditer(re.escape("if ((Get-RunningWinws2).Count -gt 0)"), strategy_test)]
    if not any("exit 1" in strategy_test[start:start + 500] for start in running_guards):
        fail("strategy test must block when another winws2.exe is running")

    if not prepare_path.is_file():
        fail("отсутствует tools/prepare-service-profile.ps1")
    prepare = prepare_path.read_text(encoding="utf-8-sig")
    for token in ["--chdir=", "service-active.txt", "WriteAllBytes", "ProfilePath"]:
        require(prepare, token, "tools/prepare-service-profile.ps1")

    prepared_profile = ROOT / "tools" / "service-test-contract.txt"
    prepare_probe = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(prepare_path),
            "-ProfilePath",
            str(ROOT / "profiles" / "general.txt"),
            "-OutputPath",
            str(prepared_profile),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
    )
    try:
        if prepare_probe.returncode != 0 or not prepared_profile.is_file():
            fail(f"service profile preparation failed: {(prepare_probe.stdout + prepare_probe.stderr).strip()}")
        prepared = prepared_profile.read_bytes()
        source = (ROOT / "profiles" / "general.txt").read_bytes()
        if not prepared.startswith(b"--chdir=") or not prepared.endswith(source):
            fail("prepared service profile does not preserve source bytes after --chdir")
    finally:
        prepared_profile.unlink(missing_ok=True)

    self_test = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(strategy_test_path),
            "-SelfTest",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
    )
    output = self_test.stdout + self_test.stderr
    match = re.search(r"SELFTEST (?:PARSER|STRUCTURE) PASS:\s+(\d+)\s+Zapret2 profiles", output)
    if self_test.returncode != 0 or not match or int(match.group(1)) < 23:
        fail(f"strategy test self-test не прошёл: {output.strip()}")

    print("PASS Flowseal-style Zapret2 service manager contract")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, subprocess.SubprocessError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
