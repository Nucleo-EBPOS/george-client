#!/usr/bin/env python3
"""GEORGE: monta um .icns a partir de PNGs (entradas PNG sao aceitas pelo macOS 10.7+)."""
import struct, subprocess, sys, tempfile, os
src, out = sys.argv[1], sys.argv[2]
types = {16: b"icp4", 32: b"icp5", 64: b"icp6", 128: b"ic07", 256: b"ic08", 512: b"ic09", 1024: b"ic10"}
body = b""
with tempfile.TemporaryDirectory() as td:
    for size, typ in types.items():
        p = os.path.join(td, f"{size}.png")
        subprocess.check_call(["convert", src, "-background", "none", "-gravity", "center",
                               "-resize", f"{size}x{size}", "-extent", f"{size}x{size}", p])
        data = open(p, "rb").read()
        body += typ + struct.pack(">I", len(data) + 8) + data
open(out, "wb").write(b"icns" + struct.pack(">I", len(body) + 8) + body)
print(out, len(body) + 8, "bytes")
