"""Observe actual shared memory helpers inside a bounded DLL child process."""
import ctypes
from _ctypes import FreeLibrary
import json
import sys

library = ctypes.WinDLL(sys.argv[1])
observed = 0
try:
    setting = library.exercise_set
    setting.argtypes = [ctypes.c_void_p, ctypes.c_int32, ctypes.c_uint64]
    setting.restype = ctypes.c_void_p
    copying = library.exercise_copy
    moving = library.exercise_move
    for operation in (copying, moving):
        operation.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint64]
        operation.restype = ctypes.c_void_p
    for count in (0, 1, 7, 31, 257):
        for value in (0, 1, -1, 511):
            storage = (ctypes.c_uint8 * 261)(*([0xA5] * 261))
            destination = ctypes.addressof(storage) + 2
            assert setting(destination, value, count) == destination
            assert bytes(storage) == bytes([0xA5] * 2 + [value & 255] * count
                                           + [0xA5] * (259 - count))
            observed += 1
        source = (ctypes.c_uint8 * 257)(*[(index * 193) & 255 for index in range(257)])
        storage = (ctypes.c_uint8 * 261)(*([0xA5] * 261))
        destination = ctypes.addressof(storage) + 2
        assert copying(destination, ctypes.addressof(source), count) == destination
        assert bytes(storage) == bytes([0xA5] * 2) + bytes(source)[:count] + bytes([0xA5] * (259 - count))
        observed += 1
    for source_offset, destination_offset, count in ((0, 3, 29), (3, 0, 29), (2, 2, 29), (0, 3, 0)):
        original = bytes(range(40))
        expected = bytearray(original)
        expected[destination_offset:destination_offset + count] = original[source_offset:source_offset + count]
        storage = (ctypes.c_uint8 * 40).from_buffer_copy(original)
        destination = ctypes.addressof(storage) + destination_offset
        assert moving(destination, ctypes.addressof(storage) + source_offset, count) == destination
        assert bytes(storage) == expected
        observed += 1
finally:
    FreeLibrary(library._handle)
print(json.dumps({"passed": True, "completed": observed, "total": 29}))
