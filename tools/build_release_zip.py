from __future__ import annotations

import argparse
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


def tracked_files(root: Path, revision: str) -> list[str]:
    result = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", "-z", revision],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return [item.decode("utf-8") for item in result.stdout.split(b"\0") if item]


def git_file(root: Path, revision: str, name: str) -> bytes:
    result = subprocess.run(
        ["git", "show", f"{revision}:{name}"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a real portable ZIP from a committed Git tree")
    parser.add_argument("--version", required=True, help="Release version, for example v1.0.1")
    parser.add_argument("--revision", default="HEAD", help="Committed Git revision to package")
    parser.add_argument("--output-dir", default="dist", help="Directory for the ZIP asset")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    output_dir = (root / args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    archive_name = f"zapret2-youtube-discord-{args.version}.zip"
    archive = output_dir / archive_name
    prefix = PurePosixPath(f"zapret2-youtube-discord-{args.version}")

    names = tracked_files(root, args.revision)
    forbidden = (".hermes/", "dist/", "__pycache__/", "tools/preset-active.txt")
    release_names = [name for name in names if not name.startswith(forbidden)]
    if not release_names:
        raise SystemExit("no tracked files selected for release")

    with tempfile.NamedTemporaryFile(dir=output_dir, suffix=".zip", delete=False) as temp:
        temporary_archive = Path(temp.name)
    try:
        with zipfile.ZipFile(temporary_archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
            for name in release_names:
                data = git_file(root, args.revision, name)
                info = zipfile.ZipInfo(str(prefix / PurePosixPath(name)), date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                bundle.writestr(info, data)
        temporary_archive.replace(archive)
    finally:
        temporary_archive.unlink(missing_ok=True)

    with zipfile.ZipFile(archive, "r") as bundle:
        bad_entry = bundle.testzip()
        if bad_entry:
            raise SystemExit(f"ZIP integrity check failed at {bad_entry}")
        archived = bundle.namelist()
    if len(archived) != len(release_names):
        raise SystemExit("ZIP file count does not match committed release tree")

    print(archive)
    print(f"ZIP_OK files={len(archived)} signature=PK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
