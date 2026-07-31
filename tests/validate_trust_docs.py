from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise AssertionError(f"{label}: missing {token!r}")


def main() -> int:
    readme = (ROOT / "README.md").read_text(encoding="utf-8-sig")
    english = (ROOT / "README.en.md").read_text(encoding="utf-8-sig")
    security = (ROOT / "SECURITY.md").read_text(encoding="utf-8-sig")
    contributing = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8-sig")
    workflow = (ROOT / ".github" / "workflows" / "build-verification.yml").read_text(
        encoding="utf-8-sig"
    )

    for token in [
        "README.en.md",
        "actions/workflows/build-verification.yml/badge.svg",
        "github/v/release/klondike0x/zapret2-youtube-discord",
        "github/downloads/klondike0x/zapret2-youtube-discord/total",
        "b5d6ed32f52a96a5ea3542d4da3bc491b9e730cccb87217332f6ae71a1cd048b",
        "2050ce15779b3595cec7320e664fa66f4ba517e978df6bd97b040803cda38535",
        "v1.0.4",
        "goshkow.com/zapret-hub/marketplace/projects/https_github_com_klondike0x_zapret2_youtube_discor",
        "Zapret Hub Marketplace",
    ]:
        require(readme, token, "README.md")
    if "c3091bb6f9fa0b6cef96763ced928ff7647eaaddc3cb04adc5cd0bfc4aa88a6f" in readme:
        raise AssertionError("README.md still presents the withdrawn v1.0.0 artifact hash")

    for token in [
        "README.md",
        "winws2.exe v1.0.3",
        "v1.0.3",
        "v1.0.4",
        "4001 5491 B3A6 3D77 7855 FEC0 8DA8 2B54 BDED 31AE",
        "VirusTotal",
        "NOTICE",
        "goshkow.com/zapret-hub/marketplace/projects/https_github_com_klondike0x_zapret2_youtube_discor",
        "Zapret Hub Marketplace",
    ]:
        require(english, token, "README.en.md")

    for token in [
        "Supported versions",
        "Private reporting",
        "fingerprint",
        "compromised",
    ]:
        require(security, token, "SECURITY.md")

    for token in [
        "pull request",
        "python tests/validate_project.py",
        "parser dry-run",
        "NOTICE",
    ]:
        require(contributing, token, "CONTRIBUTING.md")

    for token in [
        "python tools/build_release_zip.py",
        "python tests\\validate_release_zip.py",
        "actions/upload-artifact@v7",
        "actions/attest-build-provenance@v4",
        "attestations: write",
        "id-token: write",
    ]:
        require(workflow, token, "build-verification.yml")

    print("PASS trust documentation and build provenance contract")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, FileNotFoundError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
