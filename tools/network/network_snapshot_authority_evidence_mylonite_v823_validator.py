#!/usr/bin/env python3
"""Validate detached v823 authority/snapshot evidence-mylonite evidence."""
from __future__ import annotations
import argparse,hashlib,json,re
from pathlib import Path
from typing import Any

SCHEMA_VERSION=823;EVIDENCE_SCOPE="network_snapshot_authority_evidence_mylonite_v823";EVIDENCE_MODE="detached_contract_fixture";POLICY_VERSION="network_replication_interest_authority_v1";AUTHORITY="server";INTEGRITY_GATE_ID="authority-evidence-mylonite-v823";SNAPSHOT_ID="snapshot-authority-v706";ASSERTION_ID="authority-snapshot-evidence-mylonite-assertion-v1";SOURCE="server_snapshot";SNAPSHOT_VERSION=595;RELEASE_ID="release-1";SHA256=re.compile(r"^[0-9a-f]{64}$");NOT_RUN_CHECKS=("stale_check","native_run","hardware_run","human_review")

def _digest(v:Any)->bool:return isinstance(v,str)and SHA256.fullmatch(v) is not None
def _sequence(v:Any)->bool:return isinstance(v,int)and not isinstance(v,bool)and v>=0
def _assertion_digest(i:dict[str,Any])->str:return hashlib.sha256("|".join(str(i.get(k))for k in("assertion_id","integrity_gate_id","snapshot_id","sequence","subject","authority_digest","snapshot_digest")).encode()).hexdigest()
def _rollup_digest(a:list[dict[str,Any]])->str:return hashlib.sha256("\n".join(f"{i.get('order')}|{i.get('item_id')}|{i.get('assertion_digest')}"for i in a).encode()).hexdigest()
def _validate_not_run(v:Any,p:str,e:list[str])->None:
 if not isinstance(v,dict):e.append(f"{p} must be an object with NOT_RUN status");return
 if v.get("status")!="NOT_RUN":e.append(f"{p}.status must remain NOT_RUN")
 if v.get("evidence")is not None:e.append(f"{p}.evidence must be null when NOT_RUN")
 if not isinstance(v.get("reason"),str)or not v["reason"].strip():e.append(f"{p}.reason is required when NOT_RUN")
def validate_snapshot(r:Any,label:str="snapshot")->list[str]:
 e=[]
 if not isinstance(r,dict):return[f"{label} must be an object"]
 expected={"schema_version":SCHEMA_VERSION,"evidence_scope":EVIDENCE_SCOPE,"evidence_mode":EVIDENCE_MODE,"policy_version":POLICY_VERSION,"authority":AUTHORITY,"integrity_gate_id":INTEGRITY_GATE_ID,"snapshot_id":SNAPSHOT_ID,"assertion_id":ASSERTION_ID,"source":SOURCE,"snapshot_version":SNAPSHOT_VERSION,"release":RELEASE_ID}
 for k,v in expected.items():
  if r.get(k)!=v:e.append(f"{label}.{k} must be {v}")
 for k in("native_claims","uses_live_network"):
  if r.get(k)is not False:e.append(f"{label}.{k} must be false")
 for k in("snapshot_detached","no_mutation_guarantee"):
  if r.get(k)is not True:e.append(f"{label}.{k} must be true")
 for k in NOT_RUN_CHECKS:_validate_not_run(r.get(k),f"{label}.{k}",e)
 s=r.get("snapshot")
 if not isinstance(s,dict):e.append(f"{label}.snapshot must be an object");s={}
 for k,v in(("integrity_gate_id",r.get("integrity_gate_id")),("snapshot_id",r.get("snapshot_id")),("assertion_id",r.get("assertion_id")),("authority",AUTHORITY),("source",r.get("source")),("release",r.get("release")),("version",r.get("snapshot_version"))):
  if s.get(k)!=v:e.append(f"{label}.snapshot.{k} must match authority evidence mylonite")
 if not _sequence(s.get("sequence"))or not _digest(s.get("digest")):e.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")
 a=r.get("assertion_members")
 if not isinstance(a,list):e.append(f"{label}.assertion_members must be an array");a=[]
 ids=set();asserted=mutations=0
 for n,i in enumerate(a):
  p=f"{label}.assertion_members[{n}]"
  if not isinstance(i,dict):e.append(f"{p} must be an object");continue
  if i.get("order")!=n+1:e.append(f"{p}.order must be {n+1}")
  q=i.get("item_id")
  if not isinstance(q,str)or not q:e.append(f"{p}.item_id must be non-empty")
  elif q in ids:e.append(f"{p}.item_id must be unique")
  else:ids.add(q)
  for k,v in(("assertion_id",r.get("assertion_id")),("integrity_gate_id",r.get("integrity_gate_id")),("snapshot_id",r.get("snapshot_id")),("authority",AUTHORITY)):
   if i.get(k)!=v:e.append(f"{p}.{k} must bind authority evidence mylonite")
  if i.get("sequence")!=s.get("sequence"):e.append(f"{p}.sequence must match snapshot")
  if not isinstance(i.get("subject"),str)or not i["subject"]:e.append(f"{p}.subject must be non-empty")
  ad,sd=i.get("authority_digest"),i.get("snapshot_digest")
  if not _digest(ad)or not _digest(sd):e.append(f"{p} digests must be lowercase SHA-256")
  elif ad!=sd:e.append(f"{p}.snapshot_digest must match authority digest")
  z=i.get("assertion_digest")
  if not _digest(z):e.append(f"{p}.assertion_digest must be lowercase SHA-256")
  elif z!=_assertion_digest(i):e.append(f"{p}.assertion_digest must bind authority evidence mylonite")
  if i.get("asserted")is not True:e.append(f"{p}.asserted must be true")
  else:asserted+=1
  if i.get("mutation_fields")!=[]or i.get("state_changed")is not False:mutations+=1;e.append(f"{p} must have no mutation")
 z=r.get("rollup_digest")
 if not _digest(z):e.append(f"{label}.rollup_digest must be lowercase SHA-256")
 elif z!=_rollup_digest(a):e.append(f"{label}.rollup_digest must match authority evidence members")
 c=r.get("counts")
 if not isinstance(c,dict):e.append(f"{label}.counts must be an object")
 else:
  expected_counts={"assertion_members":len(a),"unique":len(ids),"asserted":asserted,"mutations":mutations}
  for k,v in expected_counts.items():
   if c.get(k)!=v:e.append(f"{label}.counts.{k} must match authority evidence members")
  if c.get("mutations")!=0:e.append(f"{label}.counts.mutations must be zero")
 return e
def validate_snapshot_file(p:Path)->list[str]:
 try:r=json.loads(p.read_text(encoding="utf-8"))
 except(OSError,json.JSONDecodeError)as x:return[f"unable to read {p}: {x}"]
 return validate_snapshot(r,str(p))
def main()->int:
 p=argparse.ArgumentParser();p.add_argument("snapshot");e=validate_snapshot_file(Path(p.parse_args().snapshot))
 if e:
  print("NETWORK_SNAPSHOT_AUTHORITY_EVIDENCE_MYLONITE_V823_INVALID")
  for x in e:print(f"- {x}")
  return 1
 print("NETWORK_SNAPSHOT_AUTHORITY_EVIDENCE_MYLONITE_V823_VALID");return 0
if __name__=="__main__":raise SystemExit(main())
