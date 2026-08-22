#!/usr/bin/env python3
"""Validate detached v418 authority/snapshot evidence-audit evidence."""
from __future__ import annotations
import argparse, hashlib, json, re
from pathlib import Path
from typing import Any

SCHEMA_VERSION=418
EVIDENCE_SCOPE="network_snapshot_authority_evidence_audit_v418"
EVIDENCE_MODE="detached_contract_fixture"
POLICY_VERSION="network_replication_interest_authority_v1"
AUTHORITY="server"
INTEGRITY_GATE_ID="authority-evidence-audit-v418"
SNAPSHOT_ID="snapshot-authority-v301"
ASSERTION_ID="authority-snapshot-evidence-audit-assertion-v1"
SOURCE="server_snapshot"
SNAPSHOT_VERSION=190
RELEASE_ID="release-1"
SHA256=re.compile(r"^[0-9a-f]{64}$")
NOT_RUN_CHECKS=("stale_check","native_run","hardware_run","human_review")

def _digest(value: Any)->bool: return isinstance(value,str) and SHA256.fullmatch(value) is not None
def _sequence(value: Any)->bool: return isinstance(value,int) and not isinstance(value,bool) and value>=0
def _assertion_digest(item: dict[str,Any])->str:
    fields=("assertion_id","integrity_gate_id","snapshot_id","sequence","subject","authority_digest","snapshot_digest")
    return hashlib.sha256("|".join(str(item.get(k)) for k in fields).encode()).hexdigest()
def _rollup_digest(items: list[dict[str,Any]])->str:
    return hashlib.sha256("\n".join(f"{x.get('order')}|{x.get('item_id')}|{x.get('assertion_digest')}" for x in items).encode()).hexdigest()
def _validate_not_run(value: Any,prefix: str,errors: list[str])->None:
    if not isinstance(value,dict): errors.append(f"{prefix} must be an object with NOT_RUN status"); return
    if value.get("status")!="NOT_RUN": errors.append(f"{prefix}.status must remain NOT_RUN")
    if value.get("evidence") is not None: errors.append(f"{prefix}.evidence must be null when NOT_RUN")
    if not isinstance(value.get("reason"),str) or not value["reason"].strip(): errors.append(f"{prefix}.reason is required when NOT_RUN")

def validate_snapshot(report: Any,label: str="snapshot")->list[str]:
    errors=[]
    if not isinstance(report,dict): return [f"{label} must be an object"]
    expected={"schema_version":SCHEMA_VERSION,"evidence_scope":EVIDENCE_SCOPE,"evidence_mode":EVIDENCE_MODE,"policy_version":POLICY_VERSION,"authority":AUTHORITY,"integrity_gate_id":INTEGRITY_GATE_ID,"snapshot_id":SNAPSHOT_ID,"assertion_id":ASSERTION_ID,"source":SOURCE,"snapshot_version":SNAPSHOT_VERSION,"release":RELEASE_ID}
    for k,v in expected.items():
        if report.get(k)!=v: errors.append(f"{label}.{k} must be {v}")
    for k in ("native_claims","uses_live_network"):
        if report.get(k) is not False: errors.append(f"{label}.{k} must be false")
    for k in ("snapshot_detached","no_mutation_guarantee"):
        if report.get(k) is not True: errors.append(f"{label}.{k} must be true")
    for k in NOT_RUN_CHECKS: _validate_not_run(report.get(k),f"{label}.{k}",errors)
    snapshot=report.get("snapshot")
    if not isinstance(snapshot,dict): errors.append(f"{label}.snapshot must be an object"); snapshot={}
    for k,v in (("integrity_gate_id",report.get("integrity_gate_id")),("snapshot_id",report.get("snapshot_id")),("assertion_id",report.get("assertion_id")),("authority",AUTHORITY),("source",report.get("source")),("release",report.get("release")),("version",report.get("snapshot_version"))):
        if snapshot.get(k)!=v: errors.append(f"{label}.snapshot.{k} must match authority evidence audit")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")): errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")
    items=report.get("assertion_members")
    if not isinstance(items,list): errors.append(f"{label}.assertion_members must be an array"); items=[]
    ids=set(); asserted=mutations=0
    for i,item in enumerate(items):
        p=f"{label}.assertion_members[{i}]"
        if not isinstance(item,dict): errors.append(f"{p} must be an object"); continue
        if item.get("order")!=i+1: errors.append(f"{p}.order must be {i+1}")
        item_id=item.get("item_id")
        if not isinstance(item_id,str) or not item_id: errors.append(f"{p}.item_id must be non-empty")
        elif item_id in ids: errors.append(f"{p}.item_id must be unique")
        else: ids.add(item_id)
        for k,v in (("assertion_id",report.get("assertion_id")),("integrity_gate_id",report.get("integrity_gate_id")),("snapshot_id",report.get("snapshot_id")),("authority",AUTHORITY)):
            if item.get(k)!=v: errors.append(f"{p}.{k} must bind authority evidence audit")
        if item.get("sequence")!=snapshot.get("sequence"): errors.append(f"{p}.sequence must match snapshot")
        if not isinstance(item.get("subject"),str) or not item["subject"]: errors.append(f"{p}.subject must be non-empty")
        ad,sd=item.get("authority_digest"),item.get("snapshot_digest")
        if not _digest(ad) or not _digest(sd): errors.append(f"{p} digests must be lowercase SHA-256")
        elif ad!=sd: errors.append(f"{p}.snapshot_digest must match authority digest")
        assertion=item.get("assertion_digest")
        if not _digest(assertion): errors.append(f"{p}.assertion_digest must be lowercase SHA-256")
        elif assertion!=_assertion_digest(item): errors.append(f"{p}.assertion_digest must bind authority evidence audit")
        if item.get("asserted") is not True: errors.append(f"{p}.asserted must be true")
        else: asserted+=1
        if item.get("mutation_fields")!=[] or item.get("state_changed") is not False: mutations+=1; errors.append(f"{p} must have no mutation")
    rollup=report.get("rollup_digest")
    if not _digest(rollup): errors.append(f"{label}.rollup_digest must be lowercase SHA-256")
    elif rollup!=_rollup_digest(items): errors.append(f"{label}.rollup_digest must match authority evidence members")
    counts=report.get("counts")
    if not isinstance(counts,dict): errors.append(f"{label}.counts must be an object")
    else:
        expected_counts={"assertion_members":len(items),"unique":len(ids),"asserted":asserted,"mutations":mutations}
        for k,v in expected_counts.items():
            if counts.get(k)!=v: errors.append(f"{label}.counts.{k} must match authority evidence members")
        if counts.get("mutations")!=0: errors.append(f"{label}.counts.mutations must be zero")
    return errors

def validate_snapshot_file(report_path: Path)->list[str]:
    try: report=json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError,json.JSONDecodeError) as exc: return [f"unable to read {report_path}: {exc}"]
    return validate_snapshot(report,str(report_path))
def main()->int:
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument("snapshot",type=Path)
    errors=validate_snapshot_file(parser.parse_args().snapshot)
    if errors:
        print("NETWORK_SNAPSHOT_AUTHORITY_EVIDENCE_AUDIT_V418_INVALID")
        for e in errors: print(f"- {e}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_EVIDENCE_AUDIT_V418_VALID"); return 0
if __name__=="__main__": raise SystemExit(main())
