"""Resolve the actual managed compiler runtime inputs for evidence hashes."""
from pathlib import Path
import stat


def input_file_identity(path: Path) -> tuple[int, int]:
    """Use filesystem identity, never WindowsPath's Unicode case equality."""
    path = Path(path).resolve()
    info = path.stat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError(f"VERIFICATION_INPUT_NOT_FILE: {path}")
    if not info.st_ino:
        raise ValueError(f"VERIFICATION_INPUT_IDENTITY_UNAVAILABLE: {path}")
    return info.st_dev, info.st_ino


def unique_input_files(paths, *, duplicate_error=None) -> list[Path]:
    """Keep the first spelling of each actual file, or reject physical aliases."""
    result = []
    identities = set()
    for candidate in paths:
        path = Path(candidate).resolve()
        identity = input_file_identity(path)
        if identity in identities:
            if duplicate_error is not None:
                raise ValueError(f"{duplicate_error}: {candidate}")
            continue
        identities.add(identity)
        result.append(path)
    return result


def managed_runtime_inputs(executable: Path) -> list[Path]:
    executable = executable.resolve()
    inputs = [executable, executable.with_suffix('.dll'),
              executable.with_suffix('.deps.json'),
              executable.with_suffix('.runtimeconfig.json'), Path(__file__).resolve()]
    for path in inputs:
        if not path.is_file():
            raise FileNotFoundError(f'MANAGED_RUNTIME_INPUT_MISSING: {path}')
    return inputs


def managed_compilation_inputs(executable: Path, standard_library_root: Path) -> list[Path]:
    """Pin the ambient stdlib loaded for repository sources, as well as the runtime.

    Callers also pin their explicit source/import manifests and LLVM toolchain.
    Embedded stdlib bytes are covered by the compiler DLL identity.
    """
    root = standard_library_root.resolve()
    if not root.is_dir():
        raise FileNotFoundError(f'MANAGED_STDLIB_ROOT_MISSING: {root}')
    sources = sorted(root.rglob('*.slg'))
    if not sources:
        raise ValueError(f'MANAGED_STDLIB_SOURCES_MISSING: {root}')
    return unique_input_files([*managed_runtime_inputs(executable), *sources])
