from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "service.bat"
CONTROL = ROOT / "tools" / "service-control.ps1"
PREPARE = ROOT / "tools" / "prepare-service-profile.ps1"


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
    ]:
        require(service, token, "service.bat")
    if "EnableDelayedExpansion" in service:
        fail("service.bat искажает пути с символом !")
    if "taskkill /IM winws2.exe" in service:
        fail("service.bat не должен завершать все процессы winws2.exe")

    if not CONTROL.is_file():
        fail("отсутствует tools/service-control.ps1")
    control = CONTROL.read_text(encoding="utf-8-sig")
    for token in [
        "$serviceName = 'winws2'",
        "$legacyServiceName = 'zapret2-youtube-discord'",
        "Get-ImageExecutable",
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
    ]:
        require(control, token, "service-control.ps1")
    if "IndexOf($exe" in control or "findstr" in control.lower():
        fail("ownership должен сравнивать разобранный executable целиком")
    if "Remove-LegacyIfOwned" not in control or "$expectedScript" not in control:
        fail("legacy service удаляется без проверки владельца")
    if "IndexOf($expectedScript" in control or ".Contains($expectedScript" in control:
        fail("legacy ownership не должен использовать поиск подстроки")
    for token in ["[Regex]::Match(", "$actualScript.Equals($expectedScript", "-NoProfile\\s+-ExecutionPolicy", "-ProfilePath"]:
        require(control, token, "legacy ownership")
    for token in ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "$hostPath.Equals($trustedHost", "$actualProfile.StartsWith($profileRoot"]:
        require(control, token, "exact legacy ownership")
    for token in ["'Disabled' { 'disabled' }", "Rollback incomplete", "legacy cleanup failed", "$LASTEXITCODE -eq 0", "$installError", "Failed to update service description"]:
        require(control, token, "transaction rollback")

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
