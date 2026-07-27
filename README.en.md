# zapret2-youtube-discord

**English** | [Русский](README.md)

A portable Windows bundle with ready-to-use BAT profiles based on the real Zapret2 engine. It uses the official `winws2.exe` and Zapret2 Lua strategies, not the Zapret1 `winws.exe`.

[Download the latest release](https://github.com/klondike0x/zapret2-youtube-discord/releases/latest)

Release GPG fingerprint: `4001 5491 B3A6 3D77 7855 FEC0 8DA8 2B54 BDED 31AE`. The public key is available in [`release-signing-key.asc`](release-signing-key.asc).

The project follows the familiar Flowseal-style workflow: choose a BAT file, approve UAC, and get a separate minimized window running the selected profile.

> Results depend on the ISP, region, and DPI configuration. A working engine and a valid profile do not guarantee that one strategy will work on every network.

## 💻 Requirements

- Windows x64;
- administrator privileges to load WinDivert;
- the Base Filtering Engine (BFE) service must be running;
- no other active `winws2.exe` instance or conflicting WinDivert-based software.

Antivirus software may classify WinDivert as a RiskTool or PUA. It is the packet interception driver required by Zapret2.

## 🛡 Security verification

Every VirusTotal report applies **only to one exact file with one exact SHA-256**. If an archive is rebuilt or changes by even one byte, the old report no longer applies.

[![VirusTotal](https://img.shields.io/badge/VirusTotal-check_release-394EFF?logo=virustotal&logoColor=white)](https://www.virustotal.com/gui/file/c3091bb6f9fa0b6cef96763ced928ff7647eaaddc3cb04adc5cd0bfc4aa88a6f)

| Version | File | SHA-256 | VirusTotal |
| --- | --- | --- | --- |
| v1.0.0 | `zapret2-youtube-discord-v1.0.0.zip` | `c3091bb6f9fa0b6cef96763ced928ff7647eaaddc3cb04adc5cd0bfc4aa88a6f` | [Open the report for this SHA-256](https://www.virustotal.com/gui/file/c3091bb6f9fa0b6cef96763ced928ff7647eaaddc3cb04adc5cd0bfc4aa88a6f) |

The SHA-256 above comes directly from the GitHub Release asset metadata. Compare it with the downloaded archive before running it:

```powershell
Get-FileHash .\zapret2-youtube-discord-v1.0.0.zip -Algorithm SHA256
```

Verify the GPG signature of the published checksum manifest:

```bash
gpg --import release-signing-key.asc
gpg --verify SHA256SUMS.txt.asc SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt
```

> [!WARNING]
> VirusTotal is an additional source of information, not an absolute security guarantee. WinDivert and `winws2.exe` may be detected as `RiskTool`, `HackTool`, or `PUA` because they intercept and modify network traffic. Review detection names, digital signatures, SHA-256 values, and binary provenance—not only the detection count.

> [!IMPORTANT]
> Do not reuse a VirusTotal link from another version or another archive. Every release must publish a new SHA-256 and a matching `https://www.virustotal.com/gui/file/<SHA256>` link.

Generate the table entry for a future release with:

```bash
python tools/generate_virustotal_table.py dist/<archive> --version vX.Y.Z
```

When the `VT_API_KEY` secret is available, `.github/workflows/release-security.yml` additionally reads the statistics of the existing report. The VirusTotal key must never be stored in the repository; it belongs only in GitHub Actions Secrets.

## 🚀 Quick start

1. Extract the project to a normal directory where programs may be executed.
2. Run one of the Flowseal-style BAT files. Recommended starting points:
   - `general.bat` — the main profile;
   - `general (ALT).bat` — the basic adaptation of Player1545's extended strategy;
   - `general (ALT2).bat` through `general (ALT14).bat` — fourteen alternative combinations of `fake`, split, and Lua mechanisms;
   - `general (SIMPLE FAKE).bat` and its three ALT variants;
   - `general (FAKE TLS AUTO).bat` and its three ALT variants;
   - additional `MULTISPLIT`, `FAKE MULTISPLIT`, `HOSTFAKESPLIT`, `YouTube`, and `Discord` profiles.
3. Approve the UAC prompt.
4. `winws2` opens in a separate minimized window. Restore it from the taskbar if you need the runtime log.

A successful startup ends with:

```text
windivert initialized. capture is started.
```

To stop manual mode, close the profile window. Only one `winws2.exe` instance should run at a time. If one is already running, a newly launched profile asks you to close the existing window first.

If startup fails, the window remains open and shows the exit code.

## ⚙️ Flowseal-style strategy catalog

The project root currently contains **28 separate BAT files**. Of these, **23** form the adapted Player1545 catalog: `general`, the `ALT` family (`ALT`, `ALT2`–`ALT14`), four `SIMPLE FAKE` variants, and four `FAKE TLS AUTO` variants. Five additional BAT files provide separate `YouTube`, `Discord`, `MULTISPLIT`, `FAKE MULTISPLIT`, and `HOSTFAKESPLIT` profiles.

The BAT files are thin wrappers. Each one passes its profile from `profiles/` to the shared `launcher.bat`. The launcher requests administrator privileges, copies the selected configuration to the short runtime name `tools/preset-active.txt`, and starts the current `bin/winws2.exe`. Bypass parameters live in the corresponding TXT profile rather than in the BAT wrapper.

The strategies were ported from the Player1545 architecture without copying its old runtime. They run on this project's `winws2.exe` v1.0.3 (`lua_compat_ver 6`) and are checked using its real parser dry-run.

### Current BAT catalog

| Family | BAT files | Profiles | Purpose |
| --- | --- | --- | --- |
| Main | `general.bat` | `profiles/general.txt` | General-purpose baseline using `fake` and `multisplit` |
| ALT | `general (ALT).bat`, `general (ALT2).bat` … `general (ALT14).bat` | `profiles/general-alt*.txt` | 15 Player1545 variants combining `fake`, `multisplit`, `hostfakesplit`, `multidisorder`, and other Lua functions |
| SIMPLE FAKE | `general (SIMPLE FAKE).bat`, `... ALT`, `... ALT2`, `... ALT3` | `profiles/general-simple-fake*.txt` | Four relatively simple variants based mainly on fake packets |
| FAKE TLS AUTO | `general (FAKE TLS AUTO).bat`, `... ALT`, `... ALT2`, `... ALT3` | `profiles/general-fake-tls-auto*.txt` | Four variants with dynamically modified TLS fakes and different split mechanisms |
| Individual mechanisms | `general (MULTISPLIT).bat`, `general (FAKE MULTISPLIT).bat`, `general (HOSTFAKESPLIT).bat` | matching `profiles/general-*.txt` files | Explicit selection of a particular TCP/TLS mechanism |
| Specialized | `general (YouTube).bat`, `general (Discord).bat` | `profiles/youtube.txt`, `profiles/discord.txt` | Compact profiles for isolated YouTube or Discord checks |

`general (ALT).bat` starts `profiles/general-alt.txt`. The profile retains the source strategy structure while using current Zapret2 syntax and Lua functions:

- QUIC on UDP 443 for the general host lists;
- Discord Voice and STUN;
- separate handling for `discord.media`;
- a separate Google profile;
- shared HTTP/TLS host lists;
- fallback rules based on `ipset-all.txt`;
- restricted profiles for game TCP and UDP traffic.

The port of `--dpi-desync-fooling=ts` uses the explicit `tcp_ts=-600000` offset. A bare `tcp_ts` without a number is invalid in Zapret2 and causes a Lua error during packet processing.

Game ports are currently disabled through the safe placeholder port `12`. This corresponds to the disabled Game Filter in the original Flowseal setup. Edit a profile deliberately if you want to enable a game port range.

## 🧪 How the strategies differ

The catalog is not a collection of copies of one command. Profiles differ in repeat counts, split positions, payload files, traffic ranges, and Lua actions. Quick guidance:

| BAT file | TCP mechanism | When to try it |
| --- | --- | --- |
| `general (SIMPLE FAKE).bat` | `fake` with `tcp_ts=-600000` | When you want the simplest and lightest variant |
| `general (MULTISPLIT).bat` | `multisplit` with `seqovl` | When fake packets are filtered or disrupt the connection |
| `general (FAKE MULTISPLIT).bat` | `fake` + `multisplit` | A more aggressive option for difficult DPI |
| `general (HOSTFAKESPLIT).bat` | `hostfakesplit` | When DPI decides based on HTTP Host or TLS SNI |
| `general (FAKE TLS AUTO).bat` | dynamic TLS fake + `multidisorder` | For TLS filtering where randomized ClientHello data may help |
| `general (YouTube).bat` | dedicated YouTube profile | For a narrow video-service check without the full General catalog |
| `general (Discord).bat` | dedicated Discord/STUN profile | For a narrow Discord check, including voice UDP |

QUIC, Discord/STUN, lists, and IP fallback remain based on the main General ALT profile in every variant. Game profiles remain disabled through port `12`.

`FAKE TLS AUTO` uses `tls_mod=rnd,dupsid,sni=www.google.com`. HTTP uses a separate static blob because TLS modifiers cannot be applied to arbitrary HTTP payloads.

The large number of files is intentional: the workflow follows the spirit of Flowseal—select a BAT file and test the strategy with your own ISP. There is no universally best variant.

`general (ALT7).bat` and `general (ALT8).bat` are intentionally identical at present. This matches the original Player1545 catalog and preserves familiar BAT names during the port.

## 📋 User lists

The General ALT profile uses the `lists/` directory:

- `lists/list-general.txt` — primary bypass domains;
- `lists/list-general-user.txt` — user-defined domains;
- `lists/list-google.txt` — separate Google list;
- `lists/list-exclude.txt` — excluded domains;
- `lists/list-exclude-user.txt` — user-defined exclusions;
- `lists/ipset-all.txt` — common IP and subnet list;
- `lists/ipset-exclude.txt` — IP exclusions;
- `lists/ipset-exclude-user.txt` — user-defined IP exclusions.

Add one domain, IP address, or CIDR per line. Do not delete the user files or leave them completely empty. Subdomains of listed domains are matched automatically.

The `files/` directory contains compact lists and payload files for other profiles. Do not mix `files/` and `lists/` paths: every profile references its own data set.

## 🔧 Running as a service

Open `service.bat` as Administrator. The menu can:

- dynamically select any `profiles/general*.txt` profile and install it as an automatic service;
- start or stop the service;
- show its status and selected profile;
- remove the service;
- run diagnostics for the engine, BFE, WinDivert, and known conflicts;
- run the Flowseal-style strategy test with HTTP, TLS 1.2, TLS 1.3, and ping checks;
- stop a manually launched `winws2.exe` from this bundle.

The service registers `bin\winws2.exe` directly, not a PowerShell wrapper. During installation, the selected profile is copied to `tools/service-active.txt` with an absolute `--chdir`, so Lua files, lists, payloads, and filters resolve from the project root. The runtime file is local and is not included in Git or release archives.

**Run Strategy Tests** can check every `profiles/general*.txt` file or a selected range. Each profile first passes the real parser dry-run and then starts with its original capture filters, including HTTPS/443. To prevent results from being mixed with another strategy, the test refuses to continue while another `winws2.exe` is already running; it never terminates processes it did not start. Results are stored locally in `tools/test results/`.

The score is only the number of successful `curl` transport connections on the current network at that moment. An HTTP error or block page can also produce a successful `curl` exit code, so the result does not prove bypass success, does not identify a universally best strategy, and does not replace real YouTube, Discord Voice, and application-level checks.

Service name:

```text
winws2
```

The `winws2` name is mandatory because the official Windows Zapret2 binary registers that fixed name with the Service Control Manager. The service display name remains `zapret2 YouTube Discord`.

Stop the service before starting a manual profile. Close a manually launched profile before installing the service.

## 📁 Project structure

```text
zapret2-youtube-discord/
├── bin/                  winws2.exe, cygwin1.dll, WinDivert, and payload files
├── lua/                  Zapret2 Lua libraries and additional functions
├── profiles/             filter and Lua strategy configurations
├── lists/                primary host lists and IP sets
├── files/                compact lists and QUIC payloads for individual profiles
├── windivert.filter/     partial WinDivert filters
├── tools/                profile preparation and winws2 launch helpers
├── tests/                structural checks and parser dry-runs
├── general*.bat          manual launchers for individual strategies
├── launcher.bat          shared launcher with UAC and a separate window
└── service.bat           service installation and management
```

Strategies are stored in `profiles/*.txt`. Main Zapret2 parameters:

- `--lua-init` loads Lua libraries;
- `--lua-desync` configures packet actions;
- `--filter-*`, `--payload`, `--hostlist`, and `--ipset` select traffic;
- `--new` starts another processing profile.

`launcher.bat` copies the selected configuration to `tools/preset-active.txt`, then starts `bin\winws2.exe @tools/preset-active.txt` from the project root in a separate minimized window. The short relative runtime profile name is necessary because the Cygwin `@config` parser is sensitive to spaces, path encoding, and line formatting.

## ✅ Project verification

Run these commands from the project root:

```cmd
bin\winws2.exe --version
python tests\validate_project.py
python tests\validate_flowseal_bat_catalog.py
python tests\validate_flowseal_alt_port.py
python tests\validate_strategy_variants.py
python tests\validate_service_manager.py
python tests\validate_readme_sync.py
python tests\dry_run_profiles.py
```

`validate_project.py` checks the project contents, BAT launcher, service integration, and engine version.

`validate_flowseal_bat_catalog.py` checks the complete set of 23 ported strategies, BAT-to-TXT mapping, CRLF formatting, Lua initialization, and dynamic service catalog.

`validate_flowseal_alt_port.py` checks the ported General ALT profile, its dependencies, CRLF formatting, and `tcp_ts` parameters, then runs the parser dry-run.

`validate_strategy_variants.py` checks characteristic parameters of five individual mechanisms, their BAT files, dynamic service-catalog coverage, and real parser dry-runs.

`validate_service_manager.py` checks the Flowseal-style service menu, direct `winws2.exe` registration, safe service-profile preparation, and the strategy tester self-test.

`validate_readme_sync.py` checks that both language versions exist, have the same section structure, and contain the same key facts in `README.md` and `README.en.md`.

`dry_run_profiles.py` creates a temporary copy of every profile with `--dry-run` inside the configuration and passes it to the real `winws2.exe`. This checks syntax, dependency loading, and Lua initialization, but does not prove that bypassing works with a particular ISP.

Close the manual profile and stop the service before a parser dry-run. Otherwise `winws2` may report:

```text
A copy of winws2 is already running with the same filter
```

The included binary reports:

```text
github version v1.0.3 (b78b52c4cd7f843da3ff0848a3430afbd401bdf2) lua_compat_ver 6
```

Do not mix `winws2.exe` and Lua files from different releases. `zapret-lib.lua` checks the API version through `NFQWS2_COMPAT_VER`.

## 🛠️ Troubleshooting

### ❌ A profile does not open

Check whether `winws2.exe` or the `winws2` service is already running. Close the active profile window or use option 8 in `service.bat` to stop the manual process from this bundle. Option 8 does not terminate the service or `winws2.exe` instances from other directories.

### ❌ The window closes immediately

Run the BAT file again and read the message in the separate window. Profile preparation errors remain in the original CMD window, while `winws2.exe` errors appear in the profile window.

### ❌ `failed to split command line options`

Do not start `winws2.exe` manually with an absolute `@config` path. Use the supplied BAT files: the launcher creates a short `tools/preset-active.txt`, preserves the required CRLF formatting, and starts it from the correct working directory.

### ❌ Lua error involving `tcp_ts`

The parameter must contain a number, for example `tcp_ts=-600000`. A bare `tcp_ts` can pass some static checks but fails during TCP packet processing.

### 🌐 The target website is still unavailable

The `capture is started` message only confirms that WinDivert started. It does not prove that the strategy is suitable for your ISP. Check DNS, domain and IP lists, then try another profile.

## 🔗 Sources

- [bol-van/zapret2](https://github.com/bol-van/zapret2)
- [bol-van/zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle)
- [basil00/WinDivert](https://github.com/basil00/WinDivert)
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) — inspiration for the simple BAT profile-selection workflow
- [Player1545/zapret-zapret2-by-player1545](https://github.com/Player1545/zapret-zapret2-by-player1545) — source catalog of Flowseal-style strategies adapted here for the current Zapret2 runtime

This project is not an official Flowseal or Player1545 build. Player1545 strategies were adapted to the current engine and this project's structure; original copyright notices and license conditions are preserved in `NOTICE`.

## 📜 License

The project's original wrapper code is distributed under the MIT License. Third-party strategies, binaries, and libraries retain their original licenses and copyrights. Full attribution for Player1545, bol-van, and WinDivert is available in [`NOTICE`](NOTICE), and complete third-party license texts are stored in [`LICENSES`](LICENSES).
