from __future__ import annotations

import argparse
import hashlib
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def vt_stats(file_hash: str, api_key: str | None) -> str:
    if not api_key:
        return "статистика не запрошена: VT_API_KEY не настроен"
    request = urllib.request.Request(
        f"https://www.virustotal.com/api/v3/files/{file_hash}",
        headers={"x-apikey": api_key},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return "файл ещё не проанализирован"
        raise
    stats = payload["data"]["attributes"]["last_analysis_stats"]
    return f"{stats.get('malicious', 0)} malicious / {stats.get('suspicious', 0)} suspicious"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a VirusTotal release table row")
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--api-key", default=None, help="Prefer VT_API_KEY environment variable in CI")
    args = parser.parse_args()

    file_hash = sha256(args.artifact)
    report = f"https://www.virustotal.com/gui/file/{file_hash}"
    status = vt_stats(file_hash, args.api_key or os.environ.get("VT_API_KEY"))
    print("| Версия | Файл | SHA-256 | VirusTotal | Статус |")
    print("| --- | --- | --- | --- | --- |")
    print(
        f"| {args.version} | `{args.artifact.name}` | `{file_hash}` | "
        f"[Открыть отчёт]({report}) | {status} |"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
