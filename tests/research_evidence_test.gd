extends SceneTree

## Machine-readable Phase-1 evidence boundary. This suite does not access the
## network or require third-party media: it validates the tracked metadata,
## rights policy, version/date distinctions, station graph and per-ship gates.

const LEDGER_PATH := "res://docs/research/source_ledger.json"
const SCHEMA_PATH := "res://docs/research/source_ledger.schema.json"
const TOPOLOGY_PATH := "res://docs/research/STATION_TOPOLOGY.md"
const SHIP_MATRIX_PATH := "res://docs/research/ship_evidence_matrix.json"
const TORRENT_SPEC_PATH := "res://docs/TORRENT_2011_RECONSTRUCTION_SPEC.md"
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")
const EXPECTED_SOURCE_IDS := [
	"A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10",
	"B1", "B2", "B3", "B4", "B5", "B6", "B7", "C1", "C2", "C3",
]
const EXPECTED_SHIP_IDS := [
	"torrent", "zenith", "arrow", "jovian", "titan", "vortex", "paradox",
	"katana", "predator", "dynamic", "utopia", "salyut", "altair", "corona",
]
const EXPECTED_GATES := [
	"identity_and_role", "name_tied_multiview", "visual_feature_index",
	"observed_role_and_handling", "timestamped_confidence", "conflicts_and_unknowns",
]
const RIGHTS_POLICY := {
	"permission_status": "permission_not_recorded",
	"redistribution_policy": "do_not_bundle_or_commit",
	"allowed_project_policy": "citation_and_limited_internal_study_only",
}

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ledger := _load_json(LEDGER_PATH)
	var schema := _load_json(SCHEMA_PATH)
	var ship_matrix := _load_json(SHIP_MATRIX_PATH)
	var topology := FileAccess.get_file_as_string(TOPOLOGY_PATH)
	var torrent_spec := FileAccess.get_file_as_string(TORRENT_SPEC_PATH)

	_test_ledger_contract(ledger)
	_test_source_entries(ledger)
	_test_b5_provenance(ledger)
	_test_schema_contract(schema)
	_test_station_topology(topology)
	_test_ship_matrix(ship_matrix)
	_test_runtime_torrent_wording(torrent_spec)
	_finish()


func _test_ledger_contract(ledger: Dictionary) -> void:
	_check(
		int(ledger.get("schema_version", 0)) == 1
		and str(ledger.get("ledger_id", "")) == "keth_shipyards_source_ledger"
		and str(ledger.get("frame_numbering", "")) == "zero_based_decoded_frame",
		"source ledger exposes the exact schema-v1 identity and zero-based frame convention"
	)
	var sources := ledger.get("sources", []) as Array
	var actual_ids: Array[String] = []
	for source_variant in sources:
		var source := source_variant as Dictionary
		actual_ids.append(str(source.get("id", "")))
	_check(actual_ids == EXPECTED_SOURCE_IDS, "ledger covers A1-A10, B1-B7 and C1-C3 exactly once in stable order")
	_check(actual_ids.size() == _unique_strings(actual_ids).size(), "source IDs are unique")


func _test_source_entries(ledger: Dictionary) -> void:
	var sources := ledger.get("sources", []) as Array
	var artifact_ids: Array[String] = []
	var every_entry_typed := true
	var every_artifact_safe := true
	var every_rights_boundary_exact := true
	var every_video_separates_dates := true
	var every_claim_bounded := true
	for source_variant in sources:
		var source := source_variant as Dictionary
		var source_id := str(source.get("id", ""))
		var tier := str(source.get("tier", ""))
		var artifacts := source.get("artifacts", []) as Array
		var dates := source.get("date_events", []) as Array
		var claims := source.get("claims_supported", []) as Array
		var limitations := source.get("limitations", []) as Array
		var rights := source.get("rights", {}) as Dictionary
		every_entry_typed = (
			every_entry_typed
			and not source_id.is_empty()
			and tier == source_id.left(1)
			and not str(source.get("title", "")).is_empty()
			and not str(source.get("source_type", "")).is_empty()
			and not artifacts.is_empty()
			and not dates.is_empty()
		)
		every_claim_bounded = every_claim_bounded and not claims.is_empty() and not limitations.is_empty()
		for artifact_variant in artifacts:
			var artifact := artifact_variant as Dictionary
			var artifact_id := str(artifact.get("artifact_id", ""))
			artifact_ids.append(artifact_id)
			var artifact_text := JSON.stringify(artifact)
			every_artifact_safe = (
				every_artifact_safe
				and artifact_id.begins_with(source_id + ".")
				and str(artifact.get("url", "")).begins_with("https://")
				and str(artifact.get("accessed_on", "")) == "2026-08-12"
				and not artifact_text.contains("/tmp/")
				and not artifact_text.contains("local_path")
			)
		for key: String in RIGHTS_POLICY:
			every_rights_boundary_exact = (
				every_rights_boundary_exact
				and str(rights.get(key, "")) == str(RIGHTS_POLICY[key])
			)
		if source_id.begins_with("B") or source_id == "C1":
			every_video_separates_dates = (
				every_video_separates_dates
				and _has_date_event(dates, "uploaded", "documented", false)
				and _has_date_event(dates, "recorded", "unknown", true)
				and _has_date_event(dates, "game_build_revision", "unknown", true)
			)
	_check(every_entry_typed, "every ledger entry binds its tier, title, source type, artifacts and date events")
	_check(every_artifact_safe, "all artifacts are HTTPS citations with stable IDs and no tracked local-media path")
	_check(artifact_ids.size() == _unique_strings(artifact_ids).size(), "artifact IDs are globally unique")
	_check(every_rights_boundary_exact, "all twenty sources default to permission-not-recorded and no redistribution")
	_check(every_video_separates_dates, "every B-tier video and C1 separates upload from unknown recording/build dates")
	_check(every_claim_bounded, "every source has at least one bounded claim and one explicit limitation")


func _test_b5_provenance(ledger: Dictionary) -> void:
	var b5 := _source_by_id(ledger, "B5")
	var rendition := b5.get("rendition", {}) as Dictionary
	var dates := b5.get("date_events", []) as Array
	_check(
		str(rendition.get("sha256", "")) == "c1f1ed745ce507729228c62deee7798c9af51d98681f2dda65acba0d5a36948d"
		and int(rendition.get("width", 0)) == 640
		and int(rendition.get("height", 0)) == 480
		and str(rendition.get("frame_rate", "")) == "30/1"
		and int(rendition.get("frame_count", 0)) == 2753,
		"B5 pins the exact inspected 640x480/30-fps/2,753-frame rendition hash without bundling it"
	)
	_check(
		_has_date_event_value(dates, "uploaded", "2011-06-29", "documented")
		and _has_date_event(dates, "recorded", "unknown", true)
		and _has_date_event(dates, "game_build_revision", "unknown", true),
		"B5 documents only the upload date while recording date and build revision stay null"
	)
	var anchors := b5.get("anchors", []) as Array
	var frame_roster: Array[int] = []
	for anchor_variant in anchors:
		var anchor := anchor_variant as Dictionary
		frame_roster.append(int(anchor.get("frame_zero_based", -1)))
	_check(frame_roster == [306, 322, 465, 1230], "B5 retains the decisive label, spawn, seat and tied-view frame anchors")


func _test_schema_contract(schema: Dictionary) -> void:
	var schema_text := JSON.stringify(schema)
	_check(
		str(schema.get("$schema", "")).contains("2020-12")
		and str(schema.get("title", "")).contains("historical source ledger"),
		"checked-in JSON Schema identifies the typed historical ledger contract"
	)
	_check(
		schema_text.contains("permission_not_recorded")
		and schema_text.contains("do_not_bundle_or_commit")
		and schema_text.contains("archive_captured")
		and schema_text.contains("game_build_revision"),
		"schema pins rights and version/date distinctions rather than relying on prose"
	)


func _test_station_topology(topology: String) -> void:
	var required_ids := [
		"OE-B2-COMB", "OE-B2-SLABS", "OE-B2-BERTHS", "OE-B3-SPAWN",
		"OE-B3-ROOM", "OE-B3-LEVELS", "OE-B2-REGEN", "OE-B5-TORRENT",
		"FX-A8-LATTICE", "L-C1-HAB", "INF-UNIFIED",
	]
	var all_ids_present := true
	for stable_id in required_ids:
		all_ids_present = all_ids_present and topology.contains("`%s`" % stable_id)
	_check(all_ids_present, "station topology registers every evidence-scoped node/edge with a stable ID")
	_check(
		topology.contains("original_era_observed")
		and topology.contains("fixed_era_only")
		and topology.contains("later_source_only")
		and topology.contains("modern_interpretation")
		and topology.contains("inferred"),
		"topology uses all five required evidence classes"
	)
	_check(
		topology.contains("## OE-B2")
		and topology.contains("## OE-B3")
		and topology.contains("## FX-A8 and L-C1")
		and topology.contains("## LIVE"),
		"historical, fixed/later, and live graphs remain separate version scopes"
	)
	_check(
		topology.contains("fleet-dock-comb")
		and topology.contains("Three short orthogonal teeth")
		and topology.contains("empty, unassigned and explicitly deferred")
		and topology.contains("no hidden full-footprint collision slab exists")
		and topology.contains("exact three existing lease-bound berths"),
		"implemented station correction preserves the evidence-backed comb silhouette without inventing a fleet mapping"
	)


func _test_ship_matrix(matrix: Dictionary) -> void:
	_check(
		int(matrix.get("schema_version", 0)) == 1
		and str(matrix.get("matrix_id", "")) == "known_keth_ship_reconstruction_gates",
		"ship evidence matrix exposes the stable schema-v1 identity"
	)
	var gate_order: Array[String] = []
	for gate in matrix.get("gate_order", []) as Array:
		gate_order.append(str(gate))
	_check(gate_order == EXPECTED_GATES, "matrix applies the same six ordered reconstruction gates to every ship")
	var ships := matrix.get("ships", []) as Array
	var ship_ids: Array[String] = []
	var all_gate_rosters_exact := true
	var all_unknowns_explicit := true
	for ship_variant in ships:
		var ship := ship_variant as Dictionary
		ship_ids.append(str(ship.get("ship_id", "")))
		var gates := ship.get("gate_status", {}) as Dictionary
		all_gate_rosters_exact = all_gate_rosters_exact and gates.size() == EXPECTED_GATES.size()
		for gate in EXPECTED_GATES:
			all_gate_rosters_exact = all_gate_rosters_exact and gates.has(gate)
		all_unknowns_explicit = (
			all_unknowns_explicit
			and not (ship.get("unknowns", []) as Array).is_empty()
			and not str(ship.get("next_evidence_gate", "")).is_empty()
		)
	_check(ship_ids == EXPECTED_SHIP_IDS, "matrix covers all fourteen currently known names in stable evidence order")
	_check(all_gate_rosters_exact, "every ship carries exactly the same six gate results")
	_check(all_unknowns_explicit, "every ship records unresolved facts and the next evidence gate")
	var policy := matrix.get("policy", {}) as Dictionary
	_check(
		int(policy.get("current_authenticated_ship_count", -1)) == 0
		and int(policy.get("current_partial_reconstruction_count", -1)) == 1
		and int(policy.get("current_provisional_candidate_count", -1)) == 2,
		"matrix truthfully reports zero authenticated ships, one partial reconstruction and two provisional candidates"
	)
	var torrent := _ship_by_id(matrix, "torrent")
	var zenith := _ship_by_id(matrix, "zenith")
	var arrow := _ship_by_id(matrix, "arrow")
	var jovian := _ship_by_id(matrix, "jovian")
	_check(str(torrent.get("implementation_status", "")) == "b5_observed_partial_reconstruction", "Torrent alone is the bounded B5-observed partial reconstruction")
	_check(str(zenith.get("implementation_status", "")) == "not_implemented_research_candidate", "Zenith's strong B7 lock remains research rather than an unreviewed implementation")
	_check(str(arrow.get("implementation_status", "")).ends_with("_frozen") and str(jovian.get("implementation_status", "")).ends_with("_frozen"), "Arrow and Jovian silhouette redesigns remain frozen pending name-to-model evidence")


func _test_runtime_torrent_wording(torrent_spec: String) -> void:
	var audit := TORRENT_DEFINITION.audit()
	_check(bool(audit.get("valid", false)), "updated Torrent definition remains valid")
	_check(
		str(audit.get("display_name", "")) == "Torrent-class Interceptor — B5-observed reconstruction"
		and str(audit.get("evidence_notes", "")).contains("recording date and live build revision are unknown"),
		"player-facing Torrent identity no longer promotes the B5 upload year to a historical revision"
	)
	_check(
		torrent_spec.begins_with("# B5-Observed Torrent Reconstruction Specification")
		and torrent_spec.contains("recording date and live build revision are unknown")
		and not torrent_spec.contains("observed 2011 Torrent")
		and not torrent_spec.contains("Decisive dated-2011 identity"),
		"Torrent reconstruction specification cleanly separates the B5 observation from unverified chronology"
	)
	var provenance_sources := [
		"res://scripts/ships/hero_ship.gd",
		"res://scenes/ships/presentation/torrent_authored_macroform.gd",
		"res://scenes/ships/presentation/torrent_authored_macroform.tscn",
		"res://assets/models/torrent/torrent_authored_asset_manifest.json",
		"res://tools/generate_torrent_authored_assets.gd",
	]
	var no_false_revision_claim := true
	for path in provenance_sources:
		var text := FileAccess.get_file_as_string(path)
		no_false_revision_claim = (
			no_false_revision_claim
			and not text.contains("\"identity_lock\": \"dated_2011\"")
			and not text.contains("\"historical_revision\": \"2011\"")
			and not text.contains("metadata/historical_revision = \"2011\"")
		)
	_check(no_false_revision_claim, "runtime, authored asset, generator and manifest no longer assert a verified 2011 revision")


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	_check(not text.is_empty() and parsed is Dictionary, "%s parses as a non-empty JSON object" % path.get_file())
	return parsed as Dictionary if parsed is Dictionary else {}


func _source_by_id(ledger: Dictionary, source_id: String) -> Dictionary:
	for source_variant in ledger.get("sources", []) as Array:
		var source := source_variant as Dictionary
		if str(source.get("id", "")) == source_id:
			return source
	return {}


func _ship_by_id(matrix: Dictionary, ship_id: String) -> Dictionary:
	for ship_variant in matrix.get("ships", []) as Array:
		var ship := ship_variant as Dictionary
		if str(ship.get("ship_id", "")) == ship_id:
			return ship
	return {}


func _has_date_event(events: Array, kind: String, status: String, require_null: bool) -> bool:
	for event_variant in events:
		var event := event_variant as Dictionary
		if str(event.get("kind", "")) != kind or str(event.get("status", "")) != status:
			continue
		if require_null and event.get("value", "sentinel") != null:
			continue
		return true
	return false


func _has_date_event_value(events: Array, kind: String, value: String, status: String) -> bool:
	for event_variant in events:
		var event := event_variant as Dictionary
		if (
			str(event.get("kind", "")) == kind
			and str(event.get("value", "")) == value
			and str(event.get("status", "")) == status
		):
			return true
	return false


func _unique_strings(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESEARCH_EVIDENCE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("RESEARCH_EVIDENCE_TEST_FAILED: %d of %d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		print(" - ", failure)
	quit(1)
