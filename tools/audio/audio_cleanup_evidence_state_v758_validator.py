#!/usr/bin/env python3
"""Validate v758 audio cleanup evidence/state summaries without runtime claims."""
from __future__ import annotations
import argparse,json,re
from pathlib import Path
from typing import Any
SCHEMA="audio_cleanup_evidence_state_v758";CLAIM="AUTOMATED_EVIDENCE_STATE_ONLY";NOT_RUN="NOT_RUN"
BOUNDARY_FIELDS=("detached_status","native_status","hardware_status","human_review_status");SHA256=re.compile(r"^[0-9a-f]{64}$")
def _text(v:Any)->bool:return isinstance(v,str) and bool(v.strip())
def _digest(v:Any)->bool:return isinstance(v,str) and SHA256.fullmatch(v) is not None
def _ids(v:Any)->bool:return isinstance(v,list) and bool(v) and all(_text(x) for x in v) and len(v)==len(set(v)) and v==sorted(v)
def validate_summary(s:Any)->list[str]:
    if not isinstance(s,dict):return ["summary must be an object"]
    e=[]
    if s.get("schema")!=SCHEMA:e.append(f"schema must be {SCHEMA}")
    for k in ("revision","owner","summary_id","evidence_bundle","evidence_id","state_model"):
        if not _text(s.get(k)):e.append(f"{k} is required")
    if s.get("claim")!=CLAIM:e.append(f"claim must be {CLAIM}")
    for k in BOUNDARY_FIELDS:
        if s.get(k)!=NOT_RUN:e.append(f"{k} must be NOT_RUN")
    if not _text(s.get("boundary_note")):e.append("boundary_note is required")
    if s.get("state") not in {"open","ready","closed"}:e.append("state must be open, ready, or closed")
    ids=s.get("record_ids")
    if not _ids(ids):e.append("record_ids must be ordered, unique, and non-empty")
    for k in ("evidence_digest","state_digest"):
        if not _digest(s.get(k)):e.append(f"{k} must be a lowercase 64-character digest")
    rs=s.get("records")
    if not isinstance(rs,list) or not rs:e.append("records must be a non-empty array");rs=[]
    seen=set()
    for i,r in enumerate(rs):
        p=f"records[{i}]"
        if not isinstance(r,dict):e.append(f"{p} must be an object");continue
        rid=r.get("record_id")
        if not _text(rid):e.append(f"{p}.record_id is required")
        elif rid in seen:e.append(f"{p}.record_id is duplicated")
        else:seen.add(rid)
        if isinstance(ids,list) and rid not in ids:e.append(f"{p}.record_id must be in record_ids")
        for k in ("evidence_digest","state_digest"):
            if not _digest(r.get(k)):e.append(f"{p}.{k} must be a lowercase 64-character digest")
            elif r.get(k)!=s.get(k):e.append(f"{p}.{k} must match summary")
        for k in ("evidence_id","state_model","state"):
            if r.get(k)!=s.get(k):e.append(f"{p}.{k} must match summary")
        if not _text(r.get("evidence")):e.append(f"{p}.evidence is required")
        if r.get("state_pass") is not True:e.append(f"{p}.state_pass must be true")
    if isinstance(ids,list) and seen!=set(ids):e.append("record_ids must exactly match records")
    if s.get("evidence_state_pass") is not True:e.append("evidence_state_pass must be true")
    return e
def main(argv:list[str]|None=None)->int:
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("summary",type=Path);s=json.loads(p.parse_args(argv).summary.read_text(encoding="utf-8"));e=validate_summary(s)
    if e:print("AUDIO_CLEANUP_EVIDENCE_STATE_V758_INVALID");print("\n".join(f"- {x}" for x in e));return 1
    print("AUDIO_CLEANUP_EVIDENCE_STATE_V758_VALID");return 0
if __name__=="__main__":raise SystemExit(main())
