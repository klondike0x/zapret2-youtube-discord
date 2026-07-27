# Security policy

## Supported versions

Only the latest published release receives security fixes. Older releases should be treated as unsupported once a replacement is available.

| Version | Supported |
| --- | --- |
| Latest release | Yes |
| Older releases | No |

## Private reporting

Do not publish suspected vulnerabilities, leaked credentials, or proof-of-concept exploits in a public issue.

Use GitHub's **Report a vulnerability** form on the repository Security page when private vulnerability reporting is available:

https://github.com/klondike0x/zapret2-youtube-discord/security/advisories/new

Include:

- the affected version and file;
- reproduction steps;
- expected and actual behavior;
- security impact;
- relevant logs with tokens and personal information removed.

If private reporting is unavailable, open a public issue containing no exploit details and ask the maintainer to establish a private contact channel.

## Official release identity

Official releases are published only at:

https://github.com/klondike0x/zapret2-youtube-discord/releases

The release-signing key fingerprint is:

```text
4001 5491 B3A6 3D77 7855 FEC0 8DA8 2B54 BDED 31AE
```

Verify the fingerprint through the repository, release notes, and an independent project announcement before trusting a newly downloaded key. A green GitHub `Verified` badge alone does not prove that an unrelated account is the official project.

Every release should contain:

- a portable ZIP;
- `SHA256SUMS.txt`;
- `SHA256SUMS.txt.asc`;
- `release-signing-key.asc`.

Verify them with:

```bash
gpg --import release-signing-key.asc
gpg --verify SHA256SUMS.txt.asc SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt
```

GPG verifies publisher identity and file integrity. It does not prove that code is harmless. VirusTotal is also an additional signal tied to a specific SHA-256, not a guarantee.

## Compromised key or account

If the signing key or GitHub account is suspected to be compromised, releases signed after the suspected compromise must not be trusted until the maintainer publishes an incident notice through independent established channels.

The response will include, as applicable:

1. pausing new releases;
2. revoking the compromised key;
3. publishing the revocation certificate and affected version range;
4. creating a new signing key;
5. publishing the new fingerprint through multiple independent channels;
6. rebuilding and re-signing affected releases under new version numbers.

A release asset will never be silently replaced while retaining an old checksum or signature.

## Scope

Reports about credential exposure, unsafe update or release behavior, command injection, privilege escalation, untrusted profile execution, or malicious release substitution are in scope.

A DPI strategy failing for a particular ISP is normally a compatibility issue rather than a security vulnerability. WinDivert RiskTool/PUA detections should include the exact SHA-256 and detection names so they can be investigated.
