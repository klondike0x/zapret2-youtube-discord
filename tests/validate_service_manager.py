from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "service.bat"
CONTROL = ROOT / "tools" / "service-control.ps1"
PREPARE = ROOT / "tools" / "prepare-service-profile.ps1"
STRATEGY_TEST = ROOT / "tools" / "test-strategies.ps1"
IMAGEPATH_TEST = ROOT / "tests" / "validate_service_imagepath.ps1"
BUILD_WORKFLOW = ROOT / ".github" / "workflows" / "build-verification.yml"
PUBLISH_WORKFLOW = ROOT / ".github" / "workflows" / "publish-release.yml"


def fail(message: str) -> None:
    raise AssertionError(message)


def require(text: str, token: str, label: str) -> None:
    if token.lower() not in text.lower():
        fail(f"{label}: отсутствует {token}")


def main() -> int:
    service = SERVICE.read_text(encoding="utf-8-sig")
    for token in [
        "service-control.ps1",
        "-Action Install",
        "-Action Remove",
        "-Action Start",
        "-Action Stop",
        "-Action Status",
        "DisableDelayedExpansion",
        "ZAPRET_SERVICE_SCRIPT",
        "WindowsBuiltInRole]::Administrator",
        "System32\\WindowsPowerShell\\v1.0\\powershell.exe",
        "COMSPEC_TRUSTED=C:\\Windows\\System32\\cmd.exe",
        "The previous working configuration",
        "stop-manual-winws2.ps1",
        "Run strategy tests",
        "test-strategies.ps1",
        "choice.exe /C 12345670",
        "choice.exe /C 1234567890",
        "EncodedCommand",
        "Convert]::ToBase64String",
    ]:
        require(service, token, "service.bat")
    if "set /p" in service.lower():
        fail("elevated service.bat не должен разбирать произвольный пользовательский ввод через set /p")
    if 'if "%menu_choice%"' in service or 'if "%profile_choice%"' in service:
        fail("elevated menu input must not be expanded as CMD source")
    for number, profile in {
        1: "profiles\\general.txt",
        2: "profiles\\general-alt.txt",
        3: "profiles\\youtube.txt",
        4: "profiles\\discord.txt",
        5: "profiles\\general-simple-fake.txt",
        6: "profiles\\general-multisplit.txt",
        7: "profiles\\general-fake-multisplit.txt",
        8: "profiles\\general-hostfakesplit.txt",
        9: "profiles\\general-fake-tls-auto.txt",
    }.items():
        require(service, f"if errorlevel {number} goto profile_{number}", "profile menu")
        require(service, f':profile_{number}', "profile menu")
        require(service, f'set "PROFILE_REL={profile}"', "profile menu")
    if 'if errorlevel 3 set "PROFILE_REL=' in service:
        fail("profile choice must branch before assigning because if errorlevel is cumulative")

    if not STRATEGY_TEST.is_file():
        fail("отсутствует tools/test-strategies.ps1")
    strategy_test = STRATEGY_TEST.read_text(encoding="utf-8-sig")
    for token in [
        "Get-ChildItem",
        "general*.txt",
        "--dry-run",
        "parameters verified",
        "curl.exe",
        "TLS1.2",
        "TLS1.3",
        "Transport observations",
        "test results",
        "Stop-TestEngine -Process",
        "Get-CimInstance Win32_Process",
        "Close manual winws2.exe before testing",
        "Get-Service -Name 'winws2'",
        "SelfTest",
        "not proof of bypass or universal effectiveness",
        "Local\\zapret2-youtube-discord-strategy-tests",
        "[guid]::NewGuid()",
        "strategy-test-$PID.txt",
        "capture is started",
        "runtime did not report capture readiness",
        "[void]$Process.WaitForExit(3000)",
        "$ErrorActionPreference = 'Continue'",
        "Strategy test failed:",
        "function Exit-WithMessage",
        "[void][Console]::ReadKey($true)",
        "Exit-WithMessage '[ERROR] Strategy tests are already running.'",
        "ZAPRET2 STRATEGY TEST REPORT",
        "TRANSPORT SUMMARY",
        "DETAILED RESULTS",
        "MAXIMUM TRANSPORT SCORE",
        "Score       : {0}",
        "Set-Content -LiteralPath $resultFile -Value $reportLines",
        "$runAborted = $true",
        "RUN STATUS: ABORTED",
        "NO TRANSPORT CHECKS CONFIGURED",
        "$detailScore = if ($item.Score -lt 0) { 'n/a' }",
        "Release-TestMutex",
        "if ($Process -and $Process.HasExited)",
        "Stop-TestEngine -Process $process",
    ]:
        require(strategy_test, token, "tools/test-strategies.ps1")
    if "general*.bat" in strategy_test:
        fail("тест должен запускать Zapret2 TXT-профили напрямую, а не разбирать BAT")
    for forbidden in ["Best strategy", "Highest transport-check score", "expected at least 23 profiles"]:
        if forbidden.lower() in strategy_test.lower():
            fail(f"strategy test содержит вводящее в заблуждение утверждение: {forbidden}")
    if "ConvertTo-Json -Depth 6 | Set-Content" in strategy_test:
        fail("TXT-отчёт не должен быть необработанным JSON-дампом")
    if "EnableDelayedExpansion" in service:
        fail("service.bat искажает пути с символом !")
    if "taskkill /IM winws2.exe" in service:
        fail("service.bat не должен завершать все процессы winws2.exe")

    if not CONTROL.is_file():
        fail("отсутствует tools/service-control.ps1")
    if not IMAGEPATH_TEST.is_file():
        fail("отсутствует tests/validate_service_imagepath.ps1")
    control = CONTROL.read_text(encoding="utf-8-sig")
    for token in [
        "$serviceName = 'winws2'",
        "$legacyServiceName = 'zapret2-youtube-discord'",
        "Get-ImageExecutable",
        "Get-ServiceConfigPath",
        "OrdinalIgnoreCase",
        "Wait-ServiceState $serviceName 'Running'",
        "Wait-ServiceState $serviceName 'Absent'",
        "service-backup.txt",
        "Remove-LegacyIfOwned",
        "Test-LegacyOwner",
        "$previousProfile",
        "$previousBinaryPath",
        "$previousStartMode",
        "$previousWasRunning",
        "$updatedExisting",
        "$activeExisted",
        "$createdRemoved",
        "$sc = 'C:\\Windows\\System32\\sc.exe'",
        "Find-ServiceRecord",
        "New-Service",
        "Start-Service",
        "Stop-Service",
        "$actualConfig.Equals($activeFull",
        "Unexpected service was preserved during rollback",
        "Global\\zapret2-youtube-discord-service-control",
        "Service manager is already running",
        "Assert-ServiceStillOwned",
        "Assert-LegacyStillOwned",
    ]:
        require(control, token, "service-control.ps1")
    if "IndexOf($exe" in control or "findstr" in control.lower():
        fail("ownership должен сравнивать разобранный executable целиком")
    if control.count("Assert-ServiceStillOwned") < 7:
        fail("ownership должен перепроверяться непосредственно перед stop/delete/config")
    if control.count("Assert-LegacyStillOwned") < 3:
        fail("legacy ownership должен перепроверяться непосредственно перед stop/delete")
    if "echo Profile not found: %PROFILE_PATH%" in service:
        fail("elevated BAT не должен интерпретировать путь как часть команды echo")
    if "Remove-LegacyIfOwned" not in control or "$expectedScript" not in control:
        fail("legacy service удаляется без проверки владельца")
    if "IndexOf($expectedScript" in control or ".Contains($expectedScript" in control:
        fail("legacy ownership не должен использовать поиск подстроки")
    for token in ["[Regex]::Match(", "$actualScript.Equals($expectedScript", "-NoProfile\\s+-ExecutionPolicy", "-ProfilePath"]:
        require(control, token, "legacy ownership")
    for token in ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "$hostPath.Equals($trustedHost", "$actualProfile.StartsWith($profileRoot"]:
        require(control, token, "exact legacy ownership")
    for token in ["'Disabled' { 'disabled' }", "Rollback incomplete", "legacy cleanup failed", "$LASTEXITCODE -ne 0", "$installError", "Failed to update service description"]:
        require(control, token, "transaction rollback")

    imagepath_probe = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(IMAGEPATH_TEST),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
    )
    if imagepath_probe.returncode != 0 or "PASS quoted and unquoted" not in imagepath_probe.stdout:
        fail(f"разбор ImagePath завершился ошибкой: {(imagepath_probe.stdout + imagepath_probe.stderr).strip()}")

    for workflow_path in [BUILD_WORKFLOW, PUBLISH_WORKFLOW]:
        workflow = workflow_path.read_text(encoding="utf-8-sig")
        if "PYTHONUTF8: 1" not in workflow:
            fail(f"{workflow_path.name}: Python UTF-8 mode is not enabled")
        for line in workflow.splitlines():
            command = line.strip()
            if command.startswith(("python tests\\", "powershell -NoProfile")) and "|| exit /b 1" not in command:
                fail(f"{workflow_path.name}: validator is not fail-fast: {command}")

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

    print("PASS winws2 transactional SCM service manager contract")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
