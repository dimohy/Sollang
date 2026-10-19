"""Hold read leases on verification contracts until their consumer terminates.

Windows sharing rules prevent writes and replacement while a lease is active.
POSIX locks coordinate cooperating writers; existing hash checks still detect
noncooperating edits on those platforms.
"""

import ctypes
import os
from pathlib import Path
from verification_fingerprints import unique_input_files


class VerificationContractLease:
    def __init__(self, paths):
        self.paths = unique_input_files(paths)
        self.handles = []
        self.mode = "windows-read-share" if os.name == "nt" else "posix-advisory-read"

    def __enter__(self):
        try:
            for path in self.paths:
                if os.name == "nt":
                    from ctypes import wintypes
                    api = ctypes.WinDLL("kernel32", use_last_error=True)
                    create = api.CreateFileW
                    create.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                       wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
                    create.restype = wintypes.HANDLE
                    handle = create(str(path), 0x80000000, 1, None, 3, 0x80, None)
                    if handle == ctypes.c_void_p(-1).value:
                        error = ctypes.get_last_error()
                        raise OSError(error, "VERIFICATION_CONTRACT_LEASE_FAILED", str(path))
                    self.handles.append((api, handle))
                else:
                    import fcntl
                    handle = path.open("rb")
                    try:
                        fcntl.flock(handle, fcntl.LOCK_SH | fcntl.LOCK_NB)
                    except BaseException:
                        handle.close()
                        raise
                    self.handles.append((None, handle))
        except BaseException:
            self.__exit__(None, None, None)
            raise
        return self

    def __exit__(self, *_):
        for api, handle in reversed(self.handles):
            if api is None:
                handle.close()
            else:
                api.CloseHandle.argtypes = [ctypes.c_void_p]
                api.CloseHandle.restype = ctypes.c_int
                api.CloseHandle(handle)
        self.handles.clear()
