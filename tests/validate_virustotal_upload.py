from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "release-security.yml"
PUBLISH_WORKFLOW = ROOT / ".github" / "workflows" / "publish-release.yml"
UPLOADER = ROOT / "tools" / "upload_virustotal.py"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    if not UPLOADER.is_file():
        return fail("tools/upload_virustotal.py is missing")

    uploader = UPLOADER.read_text(encoding="utf-8")
    for token in [
        'API_ROOT = "https://www.virustotal.com/api/v3"',
        'DIRECT_UPLOAD = f"{API_ROOT}/files"',
        'f"{API_ROOT}/analyses/',
        "upload_url",
        "VT_API_KEY",
        "x-apikey",
        "sha256",
        "completed",
        "time.sleep",
        "VIRUSTOTAL.md",
        "GITHUB_STEP_SUMMARY",
    ]:
        if token not in uploader:
            return fail(f"VirusTotal uploader misses {token}")
    if "sys.argv" in uploader and "VT_API_KEY" in uploader:
        return fail("VirusTotal API key must not be passed through argv")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in [
        "contents: write",
        "${{ secrets.VT_API_KEY }}",
        "tools/upload_virustotal.py",
        "gh release download",
        "gh release edit",
        "VIRUSTOTAL.md",
        "actions/upload-artifact@v4",
    ]:
        if token not in workflow:
            return fail(f"release workflow misses {token}")
    if '--api-key "$VT_API_KEY"' in workflow:
        return fail("workflow exposes VT_API_KEY in process arguments")
    if "dist/$RELEASE_ASSET" not in workflow:
        return fail("workflow must upload the exact redownloaded release asset")

    if not PUBLISH_WORKFLOW.is_file():
        return fail("publish-release.yml is missing")
    publish = PUBLISH_WORKFLOW.read_text(encoding="utf-8")
    for token in [
        'tags:',
        '"v*"',
        "git verify-tag",
        "tools/build_release_zip.py",
        "GPG_PRIVATE_KEY",
        "${{ secrets.VT_API_KEY }}",
        "actions/attest-build-provenance@v4",
        'gh api --method POST "repos/${{ github.repository }}/releases"',
        "-F draft=true",
        "gh release upload",
        "gh release download",
        "gpg --verify",
        "sha256sum -c",
        "tools/upload_virustotal.py",
        "--draft=false",
    ]:
        if token not in publish:
            return fail(f"publish workflow misses {token}")
    if publish.index("gh release download") > publish.index("tools/upload_virustotal.py"):
        return fail("VirusTotal must receive the ZIP redownloaded from GitHub Release")

    print("PASS automated signed release and VirusTotal upload contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
