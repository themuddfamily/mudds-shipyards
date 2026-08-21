#!/usr/bin/env python3
"""Validate v306 accessibility runtime outcome-record provenance evidence."""
from __future__ import annotations
import argparse,json,re
from pathlib import Path
from typing import Any
SCHEMA="accessibility_runtime_outcome_record_provenance_v306_evidence_v1"; SOURCE_SCHEMA="runtime_accessibility_outcome_record_policy_v1"; SCHEMA_VERSION="v306"; SOURCE_ID="runtime-accessibility-outcome-record-policy"; CONTRACT_ID="runtime-accessibility-presentation"; OPEN_REVIEW_STATUSES={"pending","not_performed","in_progress","failed"}; RECORD_STATUSES={"planned","pending","not_performed"}; EVIDENCE_KINDS={"log","image","report","video"}; SHA256=re.compile(r"^[0-9a-f]{64}$")
OUTCOME_POLICY={"sequence":["declare_scope","list_outcomes","mark_gates","defer_outcome"],"artifact_types":["validator","test","manifest","evidence"],"outcome_states":["prepared","pending_review","deferred"],"outcome_fields":["accessibility","captions","audio","bindings","camera"],"missing_artifact":"mark_incomplete_without_claim","secret_logging":"never"}; BINDING={"source_schema":SOURCE_SCHEMA,"source_id":SOURCE_ID,"contract_id":CONTRACT_ID,"policy_mode":"exact","apply_rule":"provenance_outcome_only","human_gate":"open","native_policy":"not_run"}; AUTHORITY={"presentation_only":True,"outcome_record_authority":False,"settings_read_authority":False,"settings_write_authority":False,"audio_authority":False,"caption_queue_authority":False,"gameplay_authority":False,"network_authority":False}
def _text(v:Any)->bool:return isinstance(v,str) and bool(v.strip())
def validate_runtime_outcome_record_provenance(v:Any)->list[str]:
 if not isinstance(v,dict):return ["record must be an object"]
 e=[]
 for k,x in (("schema",SCHEMA),("source_schema",SOURCE_SCHEMA),("schema_version",SCHEMA_VERSION)):
  if v.get(k)!=x:e.append(k)
 for k in ("source_revision","reviewer_required","open_gate_reason"):
  if not _text(v.get(k)):e.append(k)
 if v.get("human_review_status") not in OPEN_REVIEW_STATUSES:e.append("human_review_status")
 if v.get("native_render_status")!="not_run":e.append("native_render_status")
 for k in ("human_review_performed","native_render_performed","policy_verified","runtime_claimed","outcome_written","outcome_confirmed"):
  if v.get(k) is not False:e.append(k)
 if v.get("outcome_policy")!=OUTCOME_POLICY:e.append("outcome_policy")
 if v.get("binding")!=BINDING:e.append("binding")
 if v.get("authority")!=AUTHORITY:e.append("authority")
 for k,x in AUTHORITY.items():
  if v.get(k) is not x:e.append(k)
 if v.get("source_id")!=SOURCE_ID or v.get("contract_id")!=CONTRACT_ID or v.get("provenance_source_of_truth")!="runtime_accessibility_outcome_record_policy":e.append("provenance")
 if v.get("status") not in RECORD_STATUSES:e.append("status")
 evidence=v.get("evidence")
 if evidence is not None:
  if not isinstance(evidence,list) or not evidence:e.append("evidence")
  else:
   for item in evidence:
    if not isinstance(item,dict) or not isinstance(item.get("kind"),str) or item.get("kind") not in EVIDENCE_KINDS or not _text(item.get("path")) or not isinstance(item.get("sha256"),str) or not SHA256.fullmatch(item["sha256"]):e.append("evidence item")
 return e
def validate(path:str|Path)->list[str]:
 try:return validate_runtime_outcome_record_provenance(json.loads(Path(path).read_text(encoding="utf-8")))
 except (OSError,json.JSONDecodeError) as x:return [f"unreadable: {x}"]
def main(argv:list[str]|None=None)->int:
 p=argparse.ArgumentParser();p.add_argument("provenance",type=Path);e=validate(p.parse_args(argv).provenance)
 if e:print("ACCESSIBILITY_RUNTIME_OUTCOME_RECORD_PROVENANCE_V306_INVALID");return 1
 print("ACCESSIBILITY_RUNTIME_OUTCOME_RECORD_PROVENANCE_V306_READY: review and native gates remain open");return 0
if __name__=="__main__":raise SystemExit(main())
