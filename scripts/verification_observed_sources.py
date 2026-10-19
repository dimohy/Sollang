"""Resolve declared runtime-loaded source inputs before verification starts."""
from pathlib import Path


def observed_source_paths(root: Path, contract: dict) -> list[Path]:
    if 'observedSourceOrder' not in contract:
        return []
    names = contract['observedSourceOrder']
    if not isinstance(names, list) or not names:
        raise ValueError('OBSERVED_SOURCE_ORDER_INVALID')
    paths = []
    for name in names:
        if not isinstance(name, str) or not name:
            raise ValueError('OBSERVED_SOURCE_PATH_INVALID')
        path = (root / name).resolve()
        if not path.is_relative_to(root.resolve()) or path.suffix != '.slg' or not path.is_file():
            raise ValueError('OBSERVED_SOURCE_PATH_INVALID: ' + name)
        if path in paths:
            raise ValueError('OBSERVED_SOURCE_PATH_DUPLICATE: ' + name)
        paths.append(path)
    return paths
