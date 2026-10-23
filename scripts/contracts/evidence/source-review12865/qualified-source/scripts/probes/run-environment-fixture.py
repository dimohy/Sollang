"""Run an existing environment fixture with child-only synthetic test values."""
from pathlib import Path
import os
import subprocess
import sys

program, settings = Path(sys.argv[1]).resolve(strict=True), Path(sys.argv[2]).resolve(strict=True)
environment = os.environ.copy()
seen = set()
for line in settings.read_text(encoding='utf-8-sig').splitlines():
    if not line:
        continue
    name, separator, value = line.partition('=')
    if not separator or not name.startswith('SOLLANG_TEST_') or name in seen:
        raise ValueError('SYNTHETIC_ENVIRONMENT_FIXTURE_INVALID')
    seen.add(name)
    environment[name] = value
environment.pop('SOLLANG_TEST_MISSING', None)
result = subprocess.run([str(program)], env=environment, timeout=5)
raise SystemExit(result.returncode)
