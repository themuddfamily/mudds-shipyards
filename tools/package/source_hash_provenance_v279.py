#!/usr/bin/env python3
"""Validate version-279 package source-hash provenance evidence."""
from __future__ import annotations
import argparse,json
from pathlib import Path
from typing import Any
SCHEMA_VERSION=279;STATES={"PASS","FAIL","NOT_RUN","UNKNOWN"}
def _text(v:Any)->bool:return isinstance(v,str) and bool(v.strip())
def _count(v:Any)->bool:return isinstance(v,int) and not isinstance(v,bool) and v>=0
def _status(r:Any,l:str,e:list[str])->None:
    if not isinstance(r,dict):e.append(f"{l} must be an object");return
    s=r.get("status")
    if s not in STATES:e.append(f"{l}.status is invalid");return
    if s=="PASS" and not _text(r.get("evidence")):e.append(f"{l}.evidence is required when status is PASS")
    if s in {"NOT_RUN","UNKNOWN"} and r.get("evidence") is not None:e.append(f"{l}.evidence must be null when status is {s}")
def validate_v279(v:Any,label:str="source_provenance_v279")->list[str]:
    if not isinstance(v,dict):return [f"{label} must be an object"]
    e=[]
    if v.get("schema_version")!=SCHEMA_VERSION:e.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    tf=("build_label","source_id","provenance_id","source_commit","source_hash","source_version","package_version")
    for k in tf:
        if not _text(v.get(k)):e.append(f"{label}.{k} is required")
    cf=("source_artifact_attestation_count","package_artifact_attestation_count")
    for k in cf:
        if not _count(v.get(k)):e.append(f"{label}.{k} must be a non-negative integer")
    bf=tf[1:2]+tf[3:]+cf;s=v.get("source");_status(s,f"{label}.source",e)
    if isinstance(s,dict) and s.get("status")=="PASS":
        for k in bf:
            if s.get(k)!=v.get(k):e.append(f"{label}.source.{k} must match {k}")
        if s.get("identified") is not True:e.append(f"{label}.source.identified must be true when status is PASS")
    p=v.get("provenance");_status(p,f"{label}.provenance",e)
    if isinstance(p,dict) and p.get("status")=="PASS":
        for k in ("provenance_id",)+bf:
            if p.get(k)!=v.get(k):e.append(f"{label}.provenance.{k} must match {k}")
        if p.get("proven") is not True:e.append(f"{label}.provenance.proven must be true when status is PASS")
    for n in ("native_execution","hardware_execution","human_review"):
        g=v.get(n);_status(g,f"{label}.{n}",e)
        if isinstance(g,dict) and g.get("status")=="NOT_RUN":
            for k in ("platform","hardware","reviewer","evidence_path"):
                if g.get(k) is not None:e.append(f"{label}.{n}.{k} must be null when status is NOT_RUN")
    return e
def main(argv:list[str]|None=None)->int:
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("record",type=Path);a=p.parse_args(argv);e=validate_v279(json.loads(a.record.read_text(encoding="utf-8")))
    if e:print("SOURCE_HASH_PROVENANCE_V279_INVALID");print("\n".join(f"- {x}" for x in e));return 1
    print("SOURCE_HASH_PROVENANCE_V279_VALID");return 0
if __name__=="__main__":raise SystemExit(main())
