"""Check Korean status prose while retaining quoted source/output identifiers."""

import json
import re
import subprocess
import sys
from pathlib import Path


def foreign_prose_codepoints(text):
    prose = re.sub(r"```[\s\S]*?```|`[^`]*`|\"[^\"]*\"", "", text)
    return sorted({ord(char) for char in prose
                   if ord(char) in (0x3001, 0x3002)
                   or 0x3040 <= ord(char) <= 0x30FF
                   or 0x3400 <= ord(char) <= 0x9FFF
                   or 0xF900 <= ord(char) <= 0xFAFF})


def main():
    text = sys.stdin.buffer.read().decode("utf-8-sig")
    guard = Path("C:/Users/dimohy/.codex-b/skills/korean-software-terminology/scripts/terminology_guard.py")
    if not guard.is_file():
        raise SystemExit("KOREAN_TERMINOLOGY_GUARD_MISSING")
    result = subprocess.run([sys.executable, "-X", "utf8", str(guard), "lint-text"],
                            input=text, capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    terminology = json.loads(result.stdout)
    foreign = foreign_prose_codepoints(text)
    record = {"terminologyFindings": terminology["findings"],
              "foreignProseCodepoints": [f"U+{value:04X}" for value in foreign],
              "count": terminology["count"] + len(foreign)}
    print(json.dumps(record, ensure_ascii=False))
    raise SystemExit(1 if record["count"] else 0)


if __name__ == "__main__":
    main()
