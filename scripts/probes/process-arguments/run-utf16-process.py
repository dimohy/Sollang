"""Pass exact Windows UTF-16 code units under the caller's supervised Job."""
import json
import os
import subprocess
import sys
from pathlib import Path

if os.name != 'nt':
    raise SystemExit('WINDOWS_UTF16_PROCESS_REQUIRED')
program, encoded, destination = sys.argv[1:]
units = json.loads(encoded)
assert isinstance(units, list) and all(isinstance(arg, list) and all(
    type(unit) is int and 0 < unit <= 65535 for unit in arg) for arg in units)
arguments = [b''.join(unit.to_bytes(2, 'little') for unit in arg).decode(
    'utf-16-le', errors='surrogatepass') for arg in units]
child = subprocess.Popen([program, *arguments])
record = dict(schemaVersion=1, pid=child.pid, program=str(Path(program).resolve()),
              argumentCodeUnits=units, shutdownConfirmed=False)
try:
    record['exit'] = child.wait(timeout=30)
except subprocess.TimeoutExpired:
    child.kill()
    child.wait(timeout=5)
    record.update(timedOut=True, exit=child.returncode)
finally:
    record['shutdownConfirmed'] = child.poll() is not None
    Path(destination).write_text(json.dumps(record, ensure_ascii=True, indent=2), encoding='ascii')
raise SystemExit(124 if record.get('timedOut') else child.returncode)
