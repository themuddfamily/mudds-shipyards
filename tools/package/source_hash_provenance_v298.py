#!/usr/bin/env python3
"""Validate version-298 package provenance-node/source binding evidence."""
from __future__ import annotations
import argparse,json
from pathlib import Path
from typing import Any
SCHEMA_VERSION=298;STATES={"PASS","FAIL","NOT_RUN","UNKNOWN"}
def _text(v:Any)->bool:return isinstance(v,str) and bool(v.strip())
def _count(v:Any)->bool:return isinstance(v,int) and not isinstance(v,bool) and v>=0
def _status(v:Any,l:str,e:list[str])->None:
    if not isinstance(v,dict):e.append(f"{l} must be an object");return
    s=v.get("status")
    if s not in STATES:e.append(f"{l}.status is invalid")
    elif s=="PASS" and not _text(v.get("evidence")):e.append(f"{l}.evidence is required when status is PASS")
    elif s in {"NOT_RUN","UNKNOWN"} and v.get("evidence") is not None:e.append(f"{l}.evidence must be null when status is {s}")
def validate_v298(v:Any,label:str="source_provenance_v298")->list[str]:
    if not isinstance(v,dict):return [f"{label} must be an object"]
    e=[]
    if v.get("schema_version")!=SCHEMA_VERSION:e.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for k in ("build_label","source_id","source_commit","source_hash","package_version","node_id","node_digest"):
        if not _text(v.get(k)):e.append(f"{label}.{k} is required")
    for k in ("source_artifact_hash_count","package_artifact_hash_count","node_entry_count"):
        if not _count(v.get(k)):e.append(f"{label}.{k} must be a non-negative integer")
    b=("source_id","source_commit","source_hash","package_version","source_artifact_hash_count","package_artifact_hash_count","node_id","node_digest","node_entry_count")
    s=v.get("source");_status(s,f"{label}.source",e)
    if isinstance(s,dict) and s.get("status")=="PASS":
        for k in b:
            if s.get(k)!=v.get(k):e.append(f"{label}.source.{k} must match {k}")
        if s.get("identified") is not True:e.append(f"{label}.source.identified must be true when status is PASS")
    n=v.get("node");_status(n,f"{label}.node",e)
    if isinstance(n,dict) and n.get("status")=="PASS":
        for k in ("node_id","node_digest","source_hash","package_artifact_hash_count","node_entry_count"):
            if n.get(k)!=v.get(k):e.append(f"{label}.node.{k} must match {k}")
        if n.get("bound") is not True:e.append(f"{label}.node.bound must be true when status is PASS")
    for name in ("native_execution","hardware_execution","human_review"):
        g=v.get(name);_status(g,f"{label}.{name}",e)
        if isinstance(g,dict) and g.get("status")=="NOT_RUN":
            for k in ("platform","hardware","reviewer","evidence_path"):
                if g.get(k) is not None:e.append(f"{label}.{name}.{k} must be null when status is NOT_RUN")
    return e
def main(argv:list[str]|None=None)->int:
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("record",type=Path);a=p.parse_args(argv);e=validate_v298(json.loads(a.record.read_text(encoding="utf-8")))
    if e:print("SOURCE_HASH_PROVENANCE_V298_INVALID");print("\n".join(f"- {x}" for x in e));return 1
    print("SOURCE_HASH_PROVENANCE_V298_VALID");return 0
if __name__=="__main__":raise SystemExit(main())
