#!/usr/bin/env python3
"""Validate v382 audio cleanup evidence/state summaries without runtime claims."""
from __future__ import annotations
import argparse, json, re
from pathlib import Path
from typing import Any
SCHEMA="audio_cleanup_evidence_state_v382"; CLAIM="AUTOMATED_EVIDENCE_STATE_ONLY"; NOT_RUN="NOT_RUN"
BOUNDARY_FIELDS=("detached_status","native_status","hardware_status","human_review_status"); SHA256=re.compile(r"^[0-9a-f]{64}$")
def _text(value: Any)->bool: return isinstance(value,str) and bool(value.strip())
def _digest(value: Any)->bool: return isinstance(value,str) and SHA256.fullmatch(value) is not None
def _ids(value: Any)->bool: return isinstance(value,list) and bool(value) and all(_text(x) for x in value) and len(value)==len(set(value)) and value==sorted(value)
def validate_summary(summary: Any)->list[str]:
    if not isinstance(summary,dict): return ["summary must be an object"]
    e=[]
    if summary.get("schema")!=SCHEMA:e.append(f"schema must be {SCHEMA}")
    for k in ("revision","owner","summary_id","evidence_bundle","evidence_id","state_model"):
        if not _text(summary.get(k)):e.append(f"{k} is required")
    if summary.get("claim")!=CLAIM:e.append(f"claim must be {CLAIM}")
    for k in BOUNDARY_FIELDS:
        if summary.get(k)!=NOT_RUN:e.append(f"{k} must be NOT_RUN")
    if not _text(summary.get("boundary_note")):e.append("boundary_note is required")
    if summary.get("state") not in {"open","ready","closed"}:e.append("state must be open, ready, or closed")
    ids=summary.get("record_ids")
    if not _ids(ids):e.append("record_ids must be ordered, unique, and non-empty")
    for k in ("evidence_digest","state_digest"):
        if not _digest(summary.get(k)):e.append(f"{k} must be a lowercase 64-character digest")
    records=summary.get("records")
    if not isinstance(records,list) or not records:e.append("records must be a non-empty array"); records=[]
    seen=set()
    for i,r in enumerate(records):
        p=f"records[{i}]"
        if not isinstance(r,dict):e.append(f"{p} must be an object");continue
        rid=r.get("record_id")
        if not _text(rid):e.append(f"{p}.record_id is required")
        elif rid in seen:e.append(f"{p}.record_id is duplicated")
        else:seen.add(rid)
        if isinstance(ids,list) and rid not in ids:e.append(f"{p}.record_id must be in record_ids")
        for k in ("evidence_digest","state_digest"):
            if not _digest(r.get(k)):e.append(f"{p}.{k} must be a lowercase 64-character digest")
            elif r.get(k)!=summary.get(k):e.append(f"{p}.{k} must match summary")
        for k in ("evidence_id","state_model","state"):
            if r.get(k)!=summary.get(k):e.append(f"{p}.{k} must match summary")
        if not _text(r.get("evidence")):e.append(f"{p}.evidence is required")
        if r.get("state_pass") is not True:e.append(f"{p}.state_pass must be true")
    if isinstance(ids,list) and seen!=set(ids):e.append("record_ids must exactly match records")
    if summary.get("evidence_state_pass") is not True:e.append("evidence_state_pass must be true")
    return e
def main(argv:list[str]|None=None)->int:
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("summary",type=Path);s=json.loads(p.parse_args(argv).summary.read_text(encoding="utf-8"));e=validate_summary(s)
    if e: print("AUDIO_CLEANUP_EVIDENCE_STATE_V382_INVALID");print("\n".join(f"- {x}" for x in e));return 1
    print("AUDIO_CLEANUP_EVIDENCE_STATE_V382_VALID");return 0
if __name__=="__main__":raise SystemExit(main())
