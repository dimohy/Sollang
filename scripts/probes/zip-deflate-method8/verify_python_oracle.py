import binascii
import io
import pathlib
import sys
import zipfile
import zlib


PAYLOAD = b"Sollang-ZIP-DEFLATE-Sollang-ZIP-DEFLATE"
RAW_PAYLOAD = b"the quick brown fox jumps over the lazy dog " * 53


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_python_oracle.py <stdout-file>")
    lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
    raw_lines = [line for line in lines if line.startswith("raw=")]
    if len(raw_lines) != 1:
        raise AssertionError("expected exactly one raw DEFLATE line")
    raw = bytes(int(value) for value in raw_lines[0].removeprefix("raw=").split(",") if value)
    if (raw[0] >> 1) & 3 != 2:
        raise AssertionError("raw DEFLATE authority is not a dynamic Huffman block")
    if zlib.decompress(raw, wbits=-15) != RAW_PAYLOAD:
        raise AssertionError("raw DEFLATE dynamic Huffman/LZ payload mismatch")
    padded = raw[:-1] + bytes([raw[-1] | 0x80])
    if zlib.decompress(padded, wbits=-15) != RAW_PAYLOAD:
        raise AssertionError("raw DEFLATE final-byte padding mismatch")
    if "zip-deflate-raw=true,true,true,true" not in lines:
        raise AssertionError("Sollang raw DEFLATE bulk/byte/padding evidence missing")
    archive_lines = [line for line in lines if line.startswith("archive=")]
    if len(archive_lines) != 1:
        raise AssertionError("expected exactly one archive line")
    values = archive_lines[0].removeprefix("archive=").split(",")
    archive = bytes(int(value) for value in values if value)
    if archive[:4] != b"PK\x03\x04" or archive[8:10] != b"\x08\x00":
        raise AssertionError("local header is not ZIP DEFLATE method 8")
    with zipfile.ZipFile(io.BytesIO(archive), "r") as source:
        if source.namelist() != ["data.txt"]:
            raise AssertionError("unexpected entry set")
        info = source.getinfo("data.txt")
        if info.compress_type != zipfile.ZIP_DEFLATED:
            raise AssertionError("entry is not ZIP_DEFLATED")
        if info.file_size != len(PAYLOAD):
            raise AssertionError("decoded size mismatch")
        if info.CRC != binascii.crc32(PAYLOAD):
            raise AssertionError("CRC32 mismatch")
        if source.read(info) != PAYLOAD or source.testzip() is not None:
            raise AssertionError("decoded payload mismatch")
    print(f"PASS python zipfile method8 bytes={len(archive)} crc32={info.CRC:08X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
