"""Write structured records without exposing the destination to partial writes."""

import json
import os
from pathlib import Path
import tempfile
import time


def write_json_atomic(destination: Path, value) -> None:
    destination = Path(destination).resolve()
    # Encode before creating or opening any file. Never use the Windows locale.
    payload = (json.dumps(value, ensure_ascii=False, allow_nan=False, indent=2) + "\n").encode("utf-8")
    with tempfile.NamedTemporaryFile(
        dir=destination.parent, prefix="." + destination.name + ".", suffix=".tmp", delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
        try:
            temporary.write(payload)
            temporary.flush()
            os.fsync(temporary.fileno())
        except BaseException:
            temporary.close()
            temporary_path.unlink(missing_ok=True)
            raise
    try:
        if temporary_path.read_bytes() != payload:
            raise OSError("ATOMIC_JSON_TEMPORARY_CONTENT_MISMATCH")
        # Windows progress readers may briefly deny delete sharing. Retry only
        # the atomic publication, never the verification that produced it.
        for attempt in range(8):
            try:
                os.replace(temporary_path, destination)
                break
            except PermissionError as error:
                if getattr(error, "winerror", None) not in (5, 32, 33) or attempt == 7:
                    raise
                time.sleep(0.025)
    finally:
        temporary_path.unlink(missing_ok=True)
