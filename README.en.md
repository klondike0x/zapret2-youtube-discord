# zapret2-youtube-discord

[Русский](README.md) | English

[![Release](https://img.shields.io/github/v/release/klondike0x/zapret2-youtube-discord?label=release)](https://github.com/klondike0x/zapret2-youtube-discord/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/klondike0x/zapret2-youtube-discord/total?label=downloads)](https://github.com/klondike0x/zapret2-youtube-discord/releases)
[![Build verification](https://github.com/klondike0x/zapret2-youtube-discord/actions/workflows/build-verification.yml/badge.svg)](https://github.com/klondike0x/zapret2-youtube-discord/actions/workflows/build-verification.yml)
[![License](https://img.shields.io/github/license/klondike0x/zapret2-youtube-discord)](LICENSE)

A portable Windows toolkit with ready-to-use BAT profiles powered by the official Zapret2 engine. It uses `winws2.exe v1.0.3` with `lua_compat_ver 6`, not the legacy Zapret1 `winws.exe`.

[Download the latest release](https://github.com/klondike0x/zapret2-youtube-discord/releases/latest)

Release signing fingerprint:

```text
4001 5491 B3A6 3D77 7855 FEC0 8DA8 2B54 BDED 31AE
```

The public key is stored in [`release-signing-key.asc`](release-signing-key.asc).

> Results depend on the ISP, region, and DPI configuration. A valid profile and a running engine do not guarantee that one strategy will work on every network.

## Requirements

- Windows x64;
- administrator privileges to load WinDivert;
- the Base Filtering Engine (BFE) service;
- no other active `winws2.exe` instance or conflicting WinDivert application.

WinDivert may be reported as RiskTool or PUA because it intercepts network traffic. Such a label is not proof of infection, and a clean scan is not a guarantee of safety either.

## Quick start

1. Download and extract the latest portable ZIP.
2. Run one of the included `general*.bat` files.
3. Approve the UAC prompt.
4. Keep the minimized `winws2` window open while the profile is active.
5. Close that window to stop the manual profile.

A successful engine start ends with:

```text
windivert initialized. capture is started.
```

The current release includes general, General ALT, YouTube, Discord, Simple Fake, Multisplit, Fake Multisplit, HostFakeSplit, and Fake TLS Auto profiles. Only one profile or installed service should run at a time.

## Release verification

The corrected `v1.0.3` Windows asset is a genuine ZIP archive with Windows CRLF line endings for BAT/CMD files and Zapret2 profiles:

| Version | Asset | SHA-256 | VirusTotal |
| --- | --- | --- | --- |
| v1.0.3 | `zapret2-youtube-discord-v1.0.3.zip` | `b5d6ed32f52a96a5ea3542d4da3bc491b9e730cccb87217332f6ae71a1cd048b` | [Open report](https://www.virustotal.com/gui/file/b5d6ed32f52a96a5ea3542d4da3bc491b9e730cccb87217332f6ae71a1cd048b) |

Check the downloaded file in PowerShell:

```powershell
Get-FileHash .\zapret2-youtube-discord-v1.0.3.zip -Algorithm SHA256
```

Verify the signed checksum manifest:

```bash
gpg --import release-signing-key.asc
gpg --verify SHA256SUMS.txt.asc SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt
```

GPG proves origin and integrity, not that software is harmless. A VirusTotal report is an additional signal tied to one exact SHA-256, not an antivirus guarantee.

When a GitHub Release is published, `.github/workflows/release-security.yml` downloads the exact ZIP asset back from GitHub, verifies its SHA-256, GPG signature, CRC, and CRLF line endings, submits that same file to VirusTotal, waits for analysis, and appends the report to the Release notes. `VT_API_KEY` is stored only in GitHub Actions Secrets.

The project is also published in [goshkow's Zapret Hub Marketplace](https://goshkow.com/zapret-hub/marketplace/projects/https_github_com_klondike0x_zapret2_youtube_discor). Its listing has `published` status and passed the marketplace moderation process. This is an additional independent publication check, not a replacement for the exact release SHA-256, GPG signature, or VirusTotal report.

The `v1.0.0` asset was mistakenly packaged as TAR under a `.zip` extension. The `v1.0.1` ZIP contained LF line endings in Windows scripts and profiles. Both have been superseded by `v1.0.3`.

## Reproducing the ZIP

The release ZIP builder exports tracked files from a Git revision and writes a deterministic ZIP layout:

```bash
python tools/build_release_zip.py --version v1.0.3 --revision v1.0.3 --output-dir dist
python tests/validate_release_zip.py
```

GitHub Actions also builds and tests a ZIP from each pushed commit. For eligible runs, GitHub publishes build provenance for the generated artifact. Release checksums and detached GPG signatures remain the authoritative publisher signature for downloadable releases.

## Profiles and lists

Profiles are stored in `profiles/*.txt`. They initialize the official Zapret2 Lua libraries and define filters for TCP, QUIC, Discord voice/STUN, host lists, and IP fallback rules.

User-maintained domain and IP lists are under `lists/`. Add one domain, IP address, or CIDR per line. Do not mix `lists/` and `files/` paths because profiles use different data sets.

## Service mode

Run `service.bat` as administrator to install a selected profile as the `winws2` Windows service, shown as `zapret2 YouTube Discord`, start or stop it, inspect its status, remove it, or run strategy tests. The test option validates each profile with the real `winws2.exe`, starts profiles one at a time, and checks Discord and YouTube over HTTP, TLS 1.2, and TLS 1.3. The console can add a URL or ping host for one run, save custom targets in `tools/targets.txt`, delete them, or restore the defaults. Input is validated and is never executed as a command. Results are saved under `tools/test results/`. Stop the service and close manually launched profiles before testing. The score is network-specific transport evidence, not a guarantee that a profile bypasses every block.

## Validation

Run from the repository root:

```cmd
bin\winws2.exe --version
python tests\validate_project.py
python tests\validate_flowseal_alt_port.py
python tests\validate_strategy_variants.py
python tests\dry_run_profiles.py
```

Parser dry-runs validate configuration syntax, referenced files, and Lua initialization. They do not prove that a strategy bypasses DPI for a particular ISP.

## Security and contributions

- Security reports: [`SECURITY.md`](SECURITY.md)
- Contribution guidelines: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Third-party attribution: [`NOTICE`](NOTICE)

Pull requests with well-explained profile fixes and reproducible test results are welcome. Do not submit private keys, tokens, generated runtime files, or unlicensed third-party binaries.

## Sources and attribution

- [bol-van/zapret2](https://github.com/bol-van/zapret2)
- [bol-van/zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle)
- [basil00/WinDivert](https://github.com/basil00/WinDivert)
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube), which inspired the simple BAT-profile workflow

This is not an official Flowseal build. The project wrapper is distributed under the MIT License. Bundled third-party components retain their own licenses and copyright notices; see [`NOTICE`](NOTICE) and `LICENSES/`.
