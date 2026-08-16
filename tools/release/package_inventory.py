#!/usr/bin/env python3
"""Inspect an embedded Godot PCK and emit a deterministic JSON inventory."""
import argparse, hashlib, json, struct, sys
from pathlib import Path

FORBIDDEN = ("tests/", "artifacts/", "tools/")
RAW = (".gd", ".tscn", ".tres")

def u32(b, o): return struct.unpack_from("<I", b, o)[0]
def u64(b, o): return struct.unpack_from("<Q", b, o)[0]

def find_pck(data):
    hits=[]; p=0
    while True:
        p=data.find(b"GDPC", p)
        if p < 0: break
        hits.append(p); p += 1
    if not hits: raise ValueError("no GDPC PCK magic found")
    # Prefer a candidate with a valid conventional header and bounded entries.
    return hits[-1] if len(hits) == 1 else next((x for x in hits[::-1] if x+100 < len(data)), hits[-1])

def parse(data, base):
    if base+100 > len(data): raise ValueError("truncated PCK header")
    if data[base:base+4] != b"GDPC": raise ValueError("invalid PCK magic")
    fmt, major, minor, patch, flags = struct.unpack_from("<5I", data, base+4)
    file_base = u64(data, base+24)
    # Godot's format-4 header has 16 reserved u32 values, then file count.
    count = u32(data, base+96)
    pos = base + 100
    if count > 1000000: raise ValueError("unreasonable PCK entry count")
    if count == 0: raise ValueError("PCK uses compressed/nonstandard TOC; format-4 entry table is unavailable")
    entries=[]
    for _ in range(count):
        if pos+36 > len(data): raise ValueError("truncated PCK entry table")
        digest=data[pos:pos+16].hex(); off=u64(data,pos+16); size=u64(data,pos+24); n=u32(data,pos+32); pos+=36
        if n > len(data)-pos: raise ValueError("truncated PCK path")
        path=data[pos:pos+n].decode("utf-8"); pos += n
        absolute = base + off if off < file_base else off
        if absolute < 0 or size > len(data)-absolute: raise ValueError(f"entry outside executable: {path}")
        entries.append({"path":path,"offset":absolute,"size":size,"flags":flags,"sha256":hashlib.sha256(data[absolute:absolute+size]).hexdigest(),"pck_md5":digest})
    entries.sort(key=lambda e:e["path"])
    forbidden=[e["path"] for e in entries if e["path"].lower().startswith(FORBIDDEN) or e["path"].lower().endswith(RAW)]
    if forbidden: raise ValueError("forbidden release paths: " + ", ".join(forbidden[:8]))
    return {"schema_version":1,"pck":{"offset":base,"format":fmt,"godot_version":[major,minor,patch],"flags":flags,"file_base":file_base,"entry_count":len(entries)},"entries":entries}

def main():
    ap=argparse.ArgumentParser(description=__doc__); ap.add_argument("executable", type=Path); ap.add_argument("-o","--output", type=Path); a=ap.parse_args()
    try:
        data=a.executable.read_bytes()
        if data[:2] != b"MZ": raise ValueError("input is not a PE executable (missing MZ)")
        base=find_pck(data); result=parse(data,base)
        peoff=u32(data,0x3c) if len(data)>=64 else 0
        pe={"offset":peoff}
        if peoff+24 <= len(data) and data[peoff:peoff+4] == b"PE\\0\\0":
            pe["machine"]=struct.unpack_from("<H",data,peoff+4)[0]
            pe["sections"]=struct.unpack_from("<H",data,peoff+6)[0]
        result["executable"]={"path":str(a.executable),"sha256":hashlib.sha256(data).hexdigest(),"size":len(data),"pe":pe}
        out=json.dumps(result,sort_keys=True,indent=2)+"\n"
        if a.output: a.output.write_text(out,encoding="utf-8")
        else: sys.stdout.write(out)
    except (OSError,ValueError,struct.error,UnicodeError) as e:
        print(f"package-inventory: ERROR: {e}",file=sys.stderr); return 2
    return 0
if __name__ == "__main__": sys.exit(main())
