from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RU = ROOT / "README.md"
EN = ROOT / "README.en.md"


def fail(message: str) -> None:
    raise AssertionError(message)


def headings(text: str) -> list[tuple[int, str]]:
    result: list[tuple[int, str]] = []
    for line in text.splitlines():
        match = re.match(r"^(#{2,3})\s+(.*)$", line)
        if match:
            result.append((len(match.group(1)), match.group(2)))
    return result


def fenced_blocks(text: str) -> int:
    return sum(1 for line in text.splitlines() if line.startswith("```"))


def main() -> None:
    if not RU.is_file() or not EN.is_file():
        fail("README.md and README.en.md must both exist")

    ru = RU.read_text(encoding="utf-8-sig")
    en = EN.read_text(encoding="utf-8-sig")

    if "[English](README.en.md)" not in ru:
        fail("README.md does not link to README.en.md")
    if "[Русский](README.md)" not in en:
        fail("README.en.md does not link to README.md")

    ru_headings = headings(ru)
    en_headings = headings(en)
    if [level for level, _ in ru_headings] != [level for level, _ in en_headings]:
        fail("RU and EN heading structures differ")
    if len(ru_headings) != len(en_headings):
        fail("RU and EN section counts differ")
    if fenced_blocks(ru) != fenced_blocks(en):
        fail("RU and EN fenced-code block counts differ")

    shared_tokens = [
        "winws2.exe",
        "lua_compat_ver 6",
        "28",
        "23",
        "service-active.txt",
        "tools/test results/",
        "validate_service_manager.py",
        "c3091bb6f9fa0b6cef96763ced928ff7647eaaddc3cb04adc5cd0bfc4aa88a6f",
        "4001 5491 B3A6 3D77 7855 FEC0 8DA8 2B54 BDED 31AE",
        "Player1545",
        "Flowseal",
        "WinDivert",
    ]
    for token in shared_tokens:
        if token not in ru or token not in en:
            fail(f"shared README fact missing in one language: {token}")

    if not re.search(r"[А-Яа-яЁё]", ru):
        fail("README.md is not Russian")
    if len(re.findall(r"[А-Яа-яЁё]", en)) > 20:
        fail("README.en.md contains too much Russian text")

    print(f"PASS synchronized RU/EN README structure: {len(ru_headings)} sections")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        raise SystemExit(f"FAIL: {exc}")
