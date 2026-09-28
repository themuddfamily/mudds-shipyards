class_name NetworkSnapshotDeltaCodec
extends RefCounted

## Bounded delta envelope for authoritative snapshots. The lifecycle adapter
## remains the schema/generation authority; this codec only reconstructs a
## detached full packet before lifecycle validation.

const FULL_INTERVAL := 8
## The one nested key diffed per entry rather than as a whole: a delta carries
## only the sections that changed (`section_changes`) and the ones that went
## away (`section_removals`).
const SECTIONS_KEY := "sections"

var _baseline: Dictionary = {}
var _baseline_revision := 0
var _packets_since_full := 0


func reset() -> Dictionary:
	_baseline.clear()
	_baseline_revision = 0
	_packets_since_full = 0
	return {"accepted": true, "status": &"reset"}


func encode(packet: Dictionary, force_full: bool = false) -> Dictionary:
	var revision := int(packet.get("revision", 0))
	var full := force_full or _baseline.is_empty() or _packets_since_full >= FULL_INTERVAL
	if full:
		_baseline = packet.duplicate(true)
		_baseline_revision = revision
		_packets_since_full = 1
		return {"kind": &"full", "base_revision": 0, "revision": revision, "packet": packet.duplicate(true)}
	var previous_revision := _baseline_revision
	var changes: Dictionary = {}
	var section_changes: Dictionary = {}
	var section_removals: Array = []
	for key in packet:
		if key == "revision":
			continue
		if key == SECTIONS_KEY and packet[key] is Dictionary and _baseline.get(key) is Dictionary:
			# Sections are diffed one by one. Movement changes every tick, but
			# the ownership, boarding and landing ledgers usually do not, and
			# re-sending all of them on every 60 Hz tick multiplied the
			# reliable stream to every peer several times over.
			var sections := packet[key] as Dictionary
			var baseline_sections := _baseline[key] as Dictionary
			for section in sections:
				if not baseline_sections.has(section) or baseline_sections[section] != sections[section]:
					section_changes[section] = _detached(sections[section])
			for section in baseline_sections:
				if not sections.has(section):
					section_removals.append(section)
			continue
		if not _baseline.has(key) or _baseline[key] != packet[key]:
			changes[key] = _detached(packet[key])
	_baseline = packet.duplicate(true)
	_baseline_revision = revision
	_packets_since_full += 1
	var envelope := {
		"kind": &"delta",
		"base_revision": previous_revision,
		"revision": revision,
		"changes": changes,
	}
	if not section_changes.is_empty():
		envelope["section_changes"] = section_changes
	if not section_removals.is_empty():
		envelope["section_removals"] = section_removals
	return envelope


func decode(envelope: Dictionary) -> Dictionary:
	var kind := StringName(envelope.get("kind", &""))
	var revision := int(envelope.get("revision", 0))
	if revision <= 0:
		return {"accepted": false, "status": &"invalid_delta_revision"}
	if kind == &"full":
		var packet: Dictionary = envelope.get("packet", {}) as Dictionary
		if packet.is_empty() or int(packet.get("revision", 0)) != revision:
			return {"accepted": false, "status": &"invalid_full_snapshot"}
		_baseline = packet.duplicate(true)
		_baseline_revision = revision
		_packets_since_full = 1
		return {"accepted": true, "status": &"full_snapshot", "packet": packet.duplicate(true)}
	if kind != &"delta" or _baseline.is_empty():
		return {"accepted": false, "status": &"missing_delta_baseline"}
	if int(envelope.get("base_revision", 0)) != _baseline_revision:
		return {"accepted": false, "status": &"stale_delta_baseline"}
	var merged := _baseline.duplicate(true)
	for key in envelope.get("changes", {}):
		merged[key] = _detached(envelope.changes[key])
	var section_changes: Variant = envelope.get("section_changes", {})
	var section_removals: Variant = envelope.get("section_removals", [])
	if not (section_changes is Dictionary and section_removals is Array):
		return {"accepted": false, "status": &"invalid_section_delta"}
	if not (section_changes as Dictionary).is_empty() or not (section_removals as Array).is_empty():
		if not merged.get(SECTIONS_KEY) is Dictionary:
			return {"accepted": false, "status": &"missing_section_baseline"}
		var sections := merged[SECTIONS_KEY] as Dictionary
		for section in section_changes as Dictionary:
			sections[section] = _detached((section_changes as Dictionary)[section])
		for section in section_removals as Array:
			sections.erase(section)
	merged["revision"] = revision
	_baseline = merged.duplicate(true)
	_baseline_revision = revision
	_packets_since_full += 1
	return {"accepted": true, "status": &"delta_snapshot", "packet": merged}


static func _detached(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func get_snapshot() -> Dictionary:
	return {"baseline_revision": _baseline_revision, "packets_since_full": _packets_since_full, "has_baseline": not _baseline.is_empty()}
