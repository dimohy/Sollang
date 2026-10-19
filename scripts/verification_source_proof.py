"""Require a native compiler product to match its canonical source inputs."""

import hashlib
from pathlib import Path


def current_build_inputs(root: Path, record: dict) -> list[Path]:
    pins = record.get("inputHashesStart")
    if (record.get("status") != "passed" or record.get("inputsStable") is not True
            or not isinstance(pins, dict) or not pins or pins != record.get("inputHashesEnd")
            or not record.get("inputFingerprint")
            or record["inputFingerprint"] != record.get("finalInputFingerprint")):
        raise ValueError("PAIRED_COMPILER_SOURCE_PROOF_INCOMPLETE")
    manifest = root / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
    if str(manifest) not in pins or not manifest.is_file():
        raise ValueError("PAIRED_COMPILER_CANONICAL_MANIFEST_MISSING")
    sources = [root / line.strip() for line in manifest.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    stdlib = list((root / "stdlib").rglob("*.slg"))
    if not sources or not stdlib or any(str(path) not in pins for path in [*sources, *stdlib]):
        raise ValueError("PAIRED_COMPILER_SOURCE_CLOSURE_INCOMPLETE")
    for name, expected in pins.items():
        path = Path(name)
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest().upper() != expected.upper():
            raise ValueError("PAIRED_COMPILER_SOURCE_INPUT_DRIFT: " + name)
    return [Path(__file__).resolve(), *[Path(name) for name in pins]]
