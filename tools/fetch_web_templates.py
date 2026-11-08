"""仅下载 Godot 4.7.2 导出模板包中的 Web 模板（HTTP Range 读取 zip 中央目录）。

用途：官方 tpz 约 1.2GB，本工程当前只做 Web 冒烟测试，因此只取需要的条目。
依赖：curl、GitHub token（gh auth token）、本地代理 127.0.0.1:7897。
"""
import struct
import subprocess
import sys
import zlib
import tempfile
from pathlib import Path

ASSET_ID = "519686380"
TOTAL = 1281349702
URL = f"https://api.github.com/repos/godotengine/godot/releases/assets/{ASSET_ID}"
PROXY = "http://127.0.0.1:7897"
WANT = [
    "templates/version.txt",
    "templates/web_debug.zip",
    "templates/web_release.zip",
    "templates/web_nothreads_debug.zip",
    "templates/web_nothreads_release.zip",
]


def token() -> str:
    return subprocess.check_output(["gh", "auth", "token"], text=True).strip()


def fetch_range(tok: str, start: int, end: int, dest: Path) -> None:
    cmd = [
        "curl", "-sL", "--max-time", "300",
        "-x", PROXY,
        "-H", f"Authorization: Bearer {tok}",
        "-H", "Accept: application/octet-stream",
        "-r", f"{start}-{end}",
        "-o", str(dest), URL,
    ]
    subprocess.run(cmd, check=True)
    data = dest.read_bytes()
    if len(data) != end - start + 1:
        raise RuntimeError(f"range {start}-{end} returned {len(data)} bytes")


def main() -> None:
    tok = token()
    tmp = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(tempfile.gettempdir()) / "godot_web_templates"
    tmp.mkdir(parents=True, exist_ok=True)
    out = tmp / "4.7.2.stable"
    out.mkdir(parents=True, exist_ok=True)

    tail_path = tmp / "tail.bin"
    tail = 1 << 20
    base = TOTAL - tail
    fetch_range(tok, base, TOTAL - 1, tail_path)
    buf = tail_path.read_bytes()
    eocd = buf.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise RuntimeError("EOCD not found")
    n_total = struct.unpack_from("<H", buf, eocd + 10)[0]
    cd_size = struct.unpack_from("<I", buf, eocd + 12)[0]
    cd_off = struct.unpack_from("<I", buf, eocd + 16)[0]
    cd = buf[cd_off - base: cd_off - base + cd_size]

    entries = {}
    p = 0
    while p + 46 <= len(cd) and cd[p:p + 4] == b"PK\x01\x02":
        v = struct.unpack_from("<HHHHHHIIIHHHHHII", cd, p + 4)
        name = cd[p + 46:p + 46 + v[9]].decode("utf-8", "replace")
        entries[name] = {"comp": v[7], "uncomp": v[8], "off": v[15], "method": v[3]}
        p += 46 + v[9] + v[10] + v[11]
    print(f"central directory: {len(entries)} entries (expected {n_total})")

    for name in WANT:
        e = entries[name]
        chunk = tmp / "chunk.bin"
        # local header + compressed payload
        fetch_range(tok, e["off"], e["off"] + 30 + 512 + e["comp"] - 1, chunk)
        raw = chunk.read_bytes()
        nl, el = struct.unpack_from("<HH", raw, 26)
        data_off = 30 + nl + el
        comp = raw[data_off:data_off + e["comp"]]
        payload = zlib.decompress(comp, -15) if e["method"] == 8 else comp
        assert len(payload) == e["uncomp"], (name, len(payload), e["uncomp"])

        flat = name.removeprefix("templates/")
        (out / flat).write_bytes(payload)
        (out / "templates").mkdir(exist_ok=True)
        (out / name).write_bytes(payload)  # 同时保留原始目录结构，兼容不同 Godot 版本
        print(f"OK  {flat:36s} {len(payload):>10,} bytes")

    print("installed to:", out)


if __name__ == "__main__":
    main()
