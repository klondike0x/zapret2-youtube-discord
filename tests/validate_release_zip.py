from __future__ import annotations

import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "tools" / "build_release_zip.py"
VERSION = "v-test"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    source = BUILDER.read_text(encoding="utf-8")
    for marker in ["zipfile.ZipFile", "ZIP_DEFLATED", "git\", \"show", "testzip"]:
        if marker not in source:
            return fail(f"release ZIP builder misses {marker}")
    if "git archive" in source or "tarfile" in source:
        return fail("release ZIP builder must not create or rename a TAR archive")

    with tempfile.TemporaryDirectory(prefix="zapret-release-zip-") as temp_dir:
        output_dir = Path(temp_dir)
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--version", VERSION, "--revision", "HEAD", "--output-dir", str(output_dir)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=180,
        )
        if result.returncode != 0:
            return fail(result.stdout + result.stderr)
        archive = output_dir / f"zapret2-youtube-discord-{VERSION}.zip"
        if not archive.is_file():
            return fail("builder did not create the expected ZIP")
        if archive.read_bytes()[:4] != b"PK\x03\x04":
            return fail("release asset does not have a ZIP local-file signature")
        with zipfile.ZipFile(archive, "r") as bundle:
            if bundle.testzip() is not None:
                return fail("ZIP CRC/integrity verification failed")
            names = bundle.namelist()
        prefix = f"zapret2-youtube-discord-{VERSION}/"
        if not names or any(not name.startswith(prefix) for name in names):
            return fail("ZIP entries do not use one versioned top-level directory")
        forbidden = [name for name in names if "/.hermes/" in name or "/dist/" in name or name.endswith("tools/preset-active.txt")]
        if forbidden:
            return fail(f"ZIP contains forbidden runtime/session paths: {forbidden}")

    print(f"PASS release ZIP: files={len(names)} signature=PK integrity=OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
