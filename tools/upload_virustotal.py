from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API_ROOT = "https://www.virustotal.com/api/v3"
DIRECT_UPLOAD = f"{API_ROOT}/files"
UPLOAD_URL = f"{API_ROOT}/files/upload_url"


def request_json(url: str, api_key: str, *, method: str = "GET", data: bytes | None = None, content_type: str | None = None) -> dict:
    headers = {"x-apikey": api_key, "Accept": "application/json"}
    if content_type:
        headers["Content-Type"] = content_type
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"VirusTotal API {error.code}: {body}") from error


def multipart_file(path: Path) -> tuple[bytes, str]:
    boundary = "----zapret2VirusTotalUpload"
    header = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
        "Content-Type: application/octet-stream\r\n\r\n"
    ).encode("utf-8")
    body = header + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode("ascii")
    return body, f"multipart/form-data; boundary={boundary}"


def upload(path: Path, api_key: str) -> str:
    upload_url = DIRECT_UPLOAD
    if path.stat().st_size > 32 * 1024 * 1024:
        response = request_json(UPLOAD_URL, api_key)
        upload_url = response["data"]
    body, content_type = multipart_file(path)
    response = request_json(upload_url, api_key, method="POST", data=body, content_type=content_type)
    return response["data"]["id"]


def wait_for_analysis(analysis_id: str, api_key: str, timeout: int, interval: int) -> dict:
    deadline = time.monotonic() + timeout
    while True:
        response = request_json(f"{API_ROOT}/analyses/{urllib.parse.quote(analysis_id, safe='')}", api_key)
        attributes = response["data"]["attributes"]
        status = attributes.get("status", "unknown")
        print(f"VirusTotal analysis status: {status}", flush=True)
        if status == "completed":
            return attributes
        if time.monotonic() >= deadline:
            raise TimeoutError(f"VirusTotal analysis did not complete within {timeout} seconds")
        time.sleep(interval)


def write_report(path: Path, digest: str, attributes: dict, report_path: Path) -> str:
    stats = attributes.get("stats", {})
    url = f"https://www.virustotal.com/gui/file/{digest}"
    rows = [
        "## VirusTotal analysis",
        "",
        f"File: `{path.name}`",
        "",
        f"SHA-256: `{digest}`",
        "",
        f"Report: {url}",
        "",
        "| Result | Engines |",
        "| --- | ---: |",
    ]
    for key in ("malicious", "suspicious", "undetected", "harmless", "timeout", "failure"):
        if key in stats:
            rows.append(f"| {key} | {stats[key]} |")
    rows.extend([
        "",
        "> VirusTotal is an additional signal, not a guarantee. WinDivert and network interception tools may be classified as RiskTool, HackTool, or PUA.",
        "",
    ])
    report = "\n".join(rows)
    report_path.write_text(report, encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with Path(summary).open("a", encoding="utf-8") as stream:
            stream.write(report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description="Upload an exact release asset to VirusTotal and wait for analysis")
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--report", type=Path, default=Path("VIRUSTOTAL.md"))
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--interval", type=int, default=30)
    args = parser.parse_args()

    api_key = os.environ.get("VT_API_KEY")
    if not api_key:
        raise SystemExit("VT_API_KEY is not configured")
    path = args.artifact.resolve()
    if not path.is_file():
        raise SystemExit(f"artifact not found: {path}")

    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    analysis_id = upload(path, api_key)
    attributes = wait_for_analysis(analysis_id, api_key, args.timeout, args.interval)
    report = write_report(path, digest, attributes, args.report)
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
