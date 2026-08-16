extends SceneTree

## Machine-readable Phase-1 evidence boundary. This suite does not access the
## network or require third-party media: it validates the tracked metadata,
## rights policy, version/date distinctions, station graph and per-ship gates.

const LEDGER_PATH := "res://docs/research/source_ledger.json"
const SCHEMA_PATH := "res://docs/research/source_ledger.schema.json"
const TOPOLOGY_PATH := "res://docs/research/STATION_TOPOLOGY.md"
const SHIP_MATRIX_PATH := "res://docs/research/ship_evidence_matrix.json"
const FLEET_ROSTER_VARIANTS_PATH := "res://docs/research/fleet_roster_variants.json"
const TORRENT_SPEC_PATH := "res://docs/TORRENT_2011_RECONSTRUCTION_SPEC.md"
const RESEARCH_PATH := "res://RESEARCH.md"
const ROADMAP_PATH := "res://ROADMAP.md"
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")
const ARROW_DEFINITION := preload("res://assets/ships/arrow_provisional.tres")
const JOVIAN_DEFINITION := preload("res://assets/ships/jovian_provisional.tres")
const EVIDENCE_STATUS_VOCABULARY := [
	"authenticated", "bounded_partial_reconstruction", "provisional_candidate",
	"modern_interpretation", "unknown",
]
## Arrow and Jovian carry no name-to-model evidence at all. These are the exact
## sources whose label strings are repeatedly mistaken for a mapping, and the
## ledger claim IDs that actually hold those strings.
const UNMAPPED_CANDIDATES := {
	"arrow": {
		"label_source": "B3",
		"label_claim": "fleet.labels_titan_torrent_arrow_altair_katana",
		"anchor_word": "arrow",
		"definition_id": "arrow_provisional",
	},
	"jovian": {
		"label_source": "B4",
		"label_claim": "fleet.labels_jovian_titan_paradox_katana_vortex_predator",
		"anchor_word": "jovian",
		"definition_id": "jovian_provisional",
	},
}
## Wording that would assert a mapping the ledger does not contain. None of it
## may appear in the tracked evidence prose or the runtime evidence copy.
const PROHIBITED_MAPPING_WORDING := [
	"Arrow name-to-model lock", "Arrow name-to-model link", "B3-observed Arrow",
	"authenticated Arrow", "Arrow reconstruction", "the Arrow seen in B3",
	"Jovian name-to-model lock", "Jovian name-to-model link", "B4-observed Jovian",
	"authenticated Jovian", "Jovian reconstruction", "the Jovian seen in B4",
]
## Timestamps that were cited for the Arrow and Jovian labels but exist in no
## ledger anchor, so no independent reader could extract or check them.
const UNREGISTERED_ANCHOR_CITATIONS := [
	"B3@06:15", "06:15 regeneration label", "04:50-05:20", "4:50–5:20", "B4@04:50",
	"visible craft is labelled Paradox",
]
const ANCHOR_CITATION_SCAN_PATHS := [
	"res://RESEARCH.md",
	"res://README.md",
	"res://ROADMAP.md",
	"res://assets/ships/arrow_provisional.tres",
	"res://assets/ships/jovian_provisional.tres",
	"res://scripts/ships/arrow_recon_ship.gd",
	"res://scripts/ships/jovian_light_freighter.gd",
	"res://scripts/world/jovian_freight_berth.gd",
]
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
const FROZEN_ROSTER_VARIANT_ID := "working_fleet_vertical_slice_v1"
const CURRENT_RUNTIME_VARIANT_ID := "current_runtime_fleet_v2"
const FROZEN_MATRIX_TO_RUNTIME := {
	"torrent": "torrent_provisional",
	"zenith": "zenith_b7_observed",
	"arrow": "arrow_provisional",
	"jovian": "jovian_provisional",
}
const FROZEN_MATRIX_SHIP_IDS: Array[String] = ["torrent", "zenith", "arrow", "jovian"]
const CURRENT_RUNTIME_SHIP_IDS: Array[String] = [
	"torrent_provisional",
	"zenith_b7_observed",
	"arrow_provisional",
	"jovian_provisional",
	"halyard_new_design",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ledger := _load_json(LEDGER_PATH)
	var schema := _load_json(SCHEMA_PATH)
	var ship_matrix := _load_json(SHIP_MATRIX_PATH)
	var roster_variants := _load_json(FLEET_ROSTER_VARIANTS_PATH)
	var topology := FileAccess.get_file_as_string(TOPOLOGY_PATH)
	var torrent_spec := FileAccess.get_file_as_string(TORRENT_SPEC_PATH)

	_test_ledger_contract(ledger)
	_test_source_entries(ledger)
	_test_b5_provenance(ledger)
	_test_schema_contract(schema)
	_test_station_topology(topology)
	_test_ship_matrix(ship_matrix)
	_test_name_to_model_status_vocabulary(ship_matrix)
	_test_arrow_and_jovian_are_unmapped(ship_matrix, ledger)
	_test_arrow_and_jovian_runtime_wording()
	_test_fleet_roster_variants(roster_variants, ship_matrix, ledger)
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
		and topology.contains("Dock01 marker is externally assigned by `ShipyardWorld`")
		and topology.contains("modern Zenith berth `zenith_fleet_dock_berth`")
		# Dock02 stopped being empty when the Halyard — an original modern design,
		# not a ledger name — was parked on it. The assignment is still modern and
		# still non-authoritative, so what this suite pins is unchanged in kind:
		# the doc must name the assignment and must not launder it into
		# source-authenticated topology.
		and topology.contains("modern Halyard berth `halyard_fleet_dock_berth`")
		and topology.contains("Dock03 remains empty/deferred")
		and topology.contains("All three markers and the module itself remain non-authoritative")
		and topology.contains("FleetDockComb owns none of their berth, lease, landing, boarding, or spawn authority")
		and topology.contains("no hidden full-footprint collision slab exists")
		and topology.contains("exactly five lease-bound production berths")
		and topology.contains("no source authenticates a historical class-to-berth topology")
		and topology.contains("promoting either modern Dock01/Dock02 class assignment\ninto source-authenticated topology")
		and not topology.contains("all three dock markers are empty/deferred")
		and not topology.contains("exact three existing lease-bound berths"),
		"live topology pins the non-authoritative modern Dock01/Dock02 assignments, one deferred marker and five world-owned production berths"
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
		and int(policy.get("current_partial_reconstruction_count", -1)) == 2
		and int(policy.get("current_provisional_candidate_count", -1)) == 2,
		"matrix truthfully reports zero authenticated ships, two partial reconstructions and two provisional candidates"
	)
	var torrent := _ship_by_id(matrix, "torrent")
	var zenith := _ship_by_id(matrix, "zenith")
	var arrow := _ship_by_id(matrix, "arrow")
	var jovian := _ship_by_id(matrix, "jovian")
	_check(str(torrent.get("implementation_status", "")) == "b5_observed_partial_reconstruction", "Torrent remains the bounded B5-observed partial reconstruction")
	var zenith_scope := zenith.get("versioned_scope", {}) as Dictionary
	_check(
		str(zenith.get("implementation_status", "")) == "b7_observed_partial_reconstruction"
		and str(zenith_scope.get("scope_id", "")) == "zenith_b7_observed_interceptor"
		and str(zenith_scope.get("status", "")) == "specification_complete_implemented_bounded_partial"
		and str(zenith_scope.get("public_label", "")) == "Zenith-class Interceptor — B7-observed reconstruction"
		and str(zenith_scope.get("specification", "")) == "docs/ZENITH_B7_RECONSTRUCTION_SPEC.md",
		"Zenith is implemented only as the explicitly versioned, bounded B7-observed partial reconstruction"
	)
	_check(str(arrow.get("implementation_status", "")).ends_with("_frozen") and str(jovian.get("implementation_status", "")).ends_with("_frozen"), "Arrow and Jovian silhouette redesigns remain frozen pending name-to-model evidence")


func _test_name_to_model_status_vocabulary(matrix: Dictionary) -> void:
	var policy := matrix.get("policy", {}) as Dictionary
	var vocabulary: Array[String] = []
	for value in policy.get("evidence_status_vocabulary", []) as Array:
		vocabulary.append(str(value))
	_check(vocabulary == EVIDENCE_STATUS_VOCABULARY, "matrix policy publishes the exact five-value evidence status vocabulary")
	var every_status_in_vocabulary := true
	var unknown_count := 0
	var authenticated_ids: Array[String] = []
	for ship_variant in matrix.get("ships", []) as Array:
		var ship := ship_variant as Dictionary
		var status := str(ship.get("name_to_model_status", ""))
		every_status_in_vocabulary = every_status_in_vocabulary and vocabulary.has(status)
		if status == "unknown":
			unknown_count += 1
		if status == "authenticated":
			authenticated_ids.append(str(ship.get("ship_id", "")))
	_check(every_status_in_vocabulary, "every ship draws name_to_model_status from the controlled vocabulary")
	_check(authenticated_ids.is_empty(), "no ship claims an authenticated name-to-model mapping")
	_check(
		unknown_count == int(policy.get("current_name_to_model_unknown_count", -1)),
		"policy count of unknown name-to-model mappings matches the per-ship records"
	)
	var torrent := _ship_by_id(matrix, "torrent")
	var zenith := _ship_by_id(matrix, "zenith")
	_check(
		str(torrent.get("name_to_model_status", "")) == "bounded_partial_reconstruction"
		and str(zenith.get("name_to_model_status", "")) == "bounded_partial_reconstruction",
		"only the B5-linked Torrent and B7-observed Zenith hold a bounded name-to-model status"
	)


## Freezes the audited Arrow/Jovian boundary. Every assertion here is tied to
## what the ledger actually contains, so the statuses can only be raised by
## adding a real anchor that ties the class name to a craft.
func _test_arrow_and_jovian_are_unmapped(matrix: Dictionary, ledger: Dictionary) -> void:
	var research := FileAccess.get_file_as_string(RESEARCH_PATH)
	for ship_id: String in UNMAPPED_CANDIDATES:
		var expectation := UNMAPPED_CANDIDATES[ship_id] as Dictionary
		var ship := _ship_by_id(matrix, ship_id)
		var gates := ship.get("gate_status", {}) as Dictionary
		var label_source := str(expectation["label_source"])
		var source := _source_by_id(ledger, label_source)
		var claims: Array[String] = []
		for claim in source.get("claims_supported", []) as Array:
			claims.append(str(claim))
		_check(
			claims.has(str(expectation["label_claim"])),
			"%s still records the %s label only as the bulk label claim" % [label_source, ship_id]
		)
		var anchored := _ledger_anchor_mentions(ledger, label_source, str(expectation["anchor_word"]))
		_check(
			not anchored,
			"%s registers no frame or timestamp anchor for the %s label" % [label_source, ship_id]
		)
		# The tripwire: the status may only leave "unknown" when the ledger
		# actually gains an anchor tying that name to a craft. An implementation,
		# render or passing test can never satisfy this.
		_check(
			str(ship.get("name_to_model_status", "")) == "unknown" or anchored,
			"%s name-to-model status stays unknown until a registered %s anchor ties the name to a craft" % [ship_id, label_source]
		)
		_check(
			(ship.get("model_sources", []) as Array).is_empty(),
			"%s lists no name-to-model source" % ship_id
		)
		_check(
			(ship.get("name_only_sources", []) as Array) == [label_source],
			"%s records %s as a label-only source rather than a model source" % [ship_id, label_source]
		)
		_check(
			str(gates.get("name_tied_multiview", "")) == "fail"
			and str(gates.get("visual_feature_index", "")) == "fail"
			and str(gates.get("observed_role_and_handling", "")) == "fail",
			"%s fails the name-tied multi-view, visual-feature and observed-handling gates" % ship_id
		)
		_check(
			str(ship.get("implementation_status", "")) == "provisional_modern_candidate_frozen",
			"%s remains a frozen provisional candidate" % ship_id
		)
		_check(
			(ship.get("unknowns", []) as Array).has("name-to-model mapping")
			and not str(ship.get("name_to_model_evidence", "")).is_empty()
			and not (ship.get("prohibited_wording", []) as Array).is_empty(),
			"%s records the unknown mapping, its evidence basis and prohibited stronger wording" % ship_id
		)
	_check(
		research.contains("### Arrow and Jovian name-to-model boundary")
		and research.contains("Neither name-to-model mapping is"),
		"RESEARCH.md publishes the audited Arrow/Jovian name-to-model boundary"
	)
	var no_prohibited_wording := true
	var offending := ""
	for phrase: String in PROHIBITED_MAPPING_WORDING:
		if research.contains(phrase):
			no_prohibited_wording = false
			offending = phrase
	_check(no_prohibited_wording, "RESEARCH.md never asserts an Arrow or Jovian name-to-model mapping (%s)" % offending)
	var no_unregistered_citation := true
	for path: String in ANCHOR_CITATION_SCAN_PATHS:
		var text := FileAccess.get_file_as_string(path)
		for citation: String in UNREGISTERED_ANCHOR_CITATIONS:
			no_unregistered_citation = no_unregistered_citation and not text.contains(citation)
	_check(no_unregistered_citation, "no tracked file cites an Arrow or Jovian timestamp that the ledger does not register")


func _test_arrow_and_jovian_runtime_wording() -> void:
	var arrow_audit := ARROW_DEFINITION.audit()
	var jovian_audit := JOVIAN_DEFINITION.audit()
	_check(
		bool(arrow_audit.get("valid", false)) and bool(jovian_audit.get("valid", false)),
		"both provisional candidate definitions remain valid after the evidence rewording"
	)
	_check(
		str(arrow_audit.get("evidence_status", "")) == "provisional"
		and str(jovian_audit.get("evidence_status", "")) == "provisional"
		and not bool(arrow_audit.get("authenticated", true))
		and not bool(jovian_audit.get("authenticated", true)),
		"neither candidate definition may claim authenticated status"
	)
	for audit: Dictionary in [arrow_audit, jovian_audit]:
		var notes := str(audit.get("evidence_notes", ""))
		_check(
			notes.contains("name-to-model mapping is therefore unknown")
			and notes.contains("no registered frame anchor and no craft tied to it")
			and notes.contains("no historical name-to-model mapping is claimed"),
			"%s player-facing notes state the unknown mapping and the label-only source" % str(audit.get("ship_id", ""))
		)
		var references := audit.get("evidence_references", PackedStringArray()) as PackedStringArray
		var cites_label_only := false
		for reference in references:
			if reference.contains("label string only"):
				cites_label_only = true
		_check(cites_label_only, "%s cites its 2012 footage as a label string only" % str(audit.get("ship_id", "")))
	var runtime_sources := [
		"res://scripts/ships/arrow_recon_ship.gd",
		"res://scripts/ships/jovian_light_freighter.gd",
		"res://scripts/world/jovian_freight_berth.gd",
	]
	var runtime_declares_unknown := true
	var no_prohibited_runtime_wording := true
	for path: String in runtime_sources:
		var text := FileAccess.get_file_as_string(path)
		runtime_declares_unknown = runtime_declares_unknown and text.contains("name-to-model mapping is")
		for phrase: String in PROHIBITED_MAPPING_WORDING:
			no_prohibited_runtime_wording = no_prohibited_runtime_wording and not text.contains(phrase)
	_check(runtime_declares_unknown, "Arrow, Jovian and the freight berth repeat the unknown-mapping wording in runtime copy")
	_check(no_prohibited_runtime_wording, "runtime evidence copy never asserts an Arrow or Jovian name-to-model mapping")


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


func _test_fleet_roster_variants(
		variants: Dictionary,
		matrix: Dictionary,
		ledger: Dictionary
) -> void:
	_check(
		int(variants.get("schema_version", 0)) == 2
		and str(variants.get("document_id", "")) == "keth_shipyard_fleet_roster_variants",
		"fleet roster variants expose the runtime-aware schema-v2 identity and stable document id"
	)
	var matrix_ids: Array[String] = []
	for ship in matrix.get("ships", []) as Array:
		var ship_data := ship as Dictionary
		matrix_ids.append(str(ship_data.get("ship_id", "")))
	var source_ids: Array[String] = []
	for source in ledger.get("sources", []) as Array:
		var source_data := source as Dictionary
		source_ids.append(str(source_data.get("id", "")))
	var variants_array := variants.get("variants", []) as Array
	_check(variants_array.size() >= 3, "fleet roster variant catalog separates frozen, current-runtime, and dated-source scopes")
	var all_variant_ids_unique := true
	var dated_roster_contains_matrix_ids := false
	var evidence_links_valid := true
	var variant_ids: Array[String] = []
	var frozen_variant: Dictionary = {}
	var runtime_variant: Dictionary = {}

	for variant in variants_array:
		var variant_data := variant as Dictionary
		var variant_id := str(variant_data.get("variant_id", ""))
		var variant_type := str(variant_data.get("variant_type", ""))
		var variant_roster := variant_data.get("ships", []) as Array
		var evidence := variant_data.get("evidence_links", {}) as Dictionary
		var linked_sources := evidence.get("source_ids", []) as Array
		var linked_matrix_ids := evidence.get("matrix_ship_ids", []) as Array
		all_variant_ids_unique = all_variant_ids_unique and not variant_ids.has(variant_id) and not variant_id.is_empty()
		if not variant_id.is_empty():
			variant_ids.append(variant_id)

		for source_ref in linked_sources:
			evidence_links_valid = evidence_links_valid and (source_ids.has(str(source_ref)))
		var declared_matrix: Array[String] = []
		var declared_runtime: Array[String] = []
		var manifest_matrix: Array[String] = []
		for matrix_id in linked_matrix_ids:
			manifest_matrix.append(str(matrix_id))
		var seen_matrix := {}
		var seen_runtime := {}
		for ship_entry in variant_roster:
			var entry := ship_entry as Dictionary
			var matrix_id := str(entry.get("matrix_ship_id", ""))
			var runtime_id := str(entry.get("runtime_ship_id", ""))
			_check(
				not matrix_id.is_empty() or not runtime_id.is_empty(),
				"variant %s only lists entries with a matrix or runtime identity" % variant_id
			)
			if not matrix_id.is_empty():
				declared_matrix.append(matrix_id)
				_check(not seen_matrix.has(matrix_id), "variant %s matrix ship %s is unique" % [variant_id, matrix_id])
				seen_matrix[matrix_id] = true
				_check(matrix_ids.has(matrix_id), "variant %s references known matrix ship id %s" % [variant_id, matrix_id])
			if not runtime_id.is_empty():
				declared_runtime.append(runtime_id)
				_check(not seen_runtime.has(runtime_id), "variant %s runtime ship %s is unique" % [variant_id, runtime_id])
				seen_runtime[runtime_id] = true
			if variant_type in ["historical", "runtime"]:
				_check(
					not runtime_id.is_empty() and bool(entry.get("implemented", false)),
					"%s variant entry %s is an implemented runtime craft" % [variant_type, runtime_id]
				)
		_check(variant_id != "" and variant_data.get("scope_id", "").is_empty() == false, "every variant stores a stable variant_id and scope_id")
		_check(variant_type in ["historical", "runtime", "dated"], "each roster variant uses a recognized variant_type")
		_check(not declared_matrix.is_empty(), "variant %s explicitly lists at least one evidence-matrix ship" % variant_id)
		_check(int(variant_roster.size()) >= 1, "variant %s ships array is populated" % variant_id)
		for linked_matrix_id in manifest_matrix:
			var matrix_exists := matrix_ids.has(linked_matrix_id)
			evidence_links_valid = evidence_links_valid and matrix_exists

		if variant_id == FROZEN_ROSTER_VARIANT_ID:
			frozen_variant = variant_data
		elif variant_id == CURRENT_RUNTIME_VARIANT_ID:
			runtime_variant = variant_data
		if variant_type == "dated":
			var unique_matrix_ship_ids: Array[String] = []
			for matrix_id in manifest_matrix:
				if not unique_matrix_ship_ids.has(matrix_id):
					unique_matrix_ship_ids.append(matrix_id)
			dated_roster_contains_matrix_ids = _set_is_subset(
				matrix_ids,
				manifest_matrix
			)
			_check(unique_matrix_ship_ids.size() == matrix_ids.size(), "dated source variant includes each known matrix ship id once")

		_check(seen_matrix.size() == declared_matrix.size(), "variant %s matrix declarations are unique" % variant_id)
		_check(seen_runtime.size() == declared_runtime.size(), "variant %s runtime declarations are unique" % variant_id)
		_check(variant_id != "" and variant_data.get("scope_summary", "").is_empty() == false, "variant %s stores a non-empty scope summary" % variant_id)

	_check(all_variant_ids_unique, "all roster variant IDs are unique and non-empty")
	_test_frozen_four_craft_variant(frozen_variant)
	_test_current_runtime_variant(runtime_variant)
	_check(dated_roster_contains_matrix_ids, "dated roster variant includes every known matrix roster ID")
	_check(evidence_links_valid, "every evidence source link exists in the source ledger")


func _test_frozen_four_craft_variant(variant: Dictionary) -> void:
	_check(not variant.is_empty(), "the stable frozen four-craft variant remains present")
	if variant.is_empty():
		return
	var entries := variant.get("ships", []) as Array
	var by_runtime := _entries_by_runtime_id(entries)
	var linked_matrix := _string_array(
		((variant.get("evidence_links", {}) as Dictionary).get("matrix_ship_ids", []) as Array)
	)
	_check(
		str(variant.get("variant_type", "")) == "historical"
		and str(variant.get("scope_id", "")) == "frozen_four_craft_vertical_slice_v1",
		"working_fleet_vertical_slice_v1 is explicitly a frozen historical baseline"
	)
	_check(entries.size() == 4 and by_runtime.size() == 4, "the frozen baseline retains exactly four runtime entries")
	_check(
		_string_set_matches(FROZEN_MATRIX_SHIP_IDS, linked_matrix),
		"the frozen baseline retains exactly its four evidence-matrix identities"
	)
	var exact_pairs := true
	for matrix_id: String in FROZEN_MATRIX_TO_RUNTIME:
		var runtime_id := str(FROZEN_MATRIX_TO_RUNTIME[matrix_id])
		var entry := by_runtime.get(runtime_id, {}) as Dictionary
		exact_pairs = exact_pairs and str(entry.get("matrix_ship_id", "")) == matrix_id
	_check(exact_pairs, "the frozen baseline preserves all four original matrix-to-runtime identity pairs")


func _test_current_runtime_variant(variant: Dictionary) -> void:
	_check(not variant.is_empty(), "the current five-craft runtime variant is present")
	if variant.is_empty():
		return
	var entries := variant.get("ships", []) as Array
	var by_runtime := _entries_by_runtime_id(entries)
	var runtime_ids: Array[String] = []
	for runtime_id in by_runtime:
		runtime_ids.append(str(runtime_id))
	var evidence := variant.get("evidence_links", {}) as Dictionary
	var linked_matrix := _string_array(evidence.get("matrix_ship_ids", []) as Array)
	_check(
		str(variant.get("variant_type", "")) == "runtime"
		and str(variant.get("scope_id", "")) == "current_production_registry",
		"current_runtime_fleet_v2 is explicitly the current runtime registry"
	)
	_check(
		entries.size() == 5
		and _string_set_matches(CURRENT_RUNTIME_SHIP_IDS, runtime_ids),
		"current runtime variant lists exactly the five production flyable identities"
	)
	_check(
		_string_set_matches(FROZEN_MATRIX_SHIP_IDS, linked_matrix),
		"current runtime evidence links remain bounded to the four ledger-backed craft"
	)
	var exact_evidence_pairs := true
	for matrix_id: String in FROZEN_MATRIX_TO_RUNTIME:
		var runtime_id := str(FROZEN_MATRIX_TO_RUNTIME[matrix_id])
		var entry := by_runtime.get(runtime_id, {}) as Dictionary
		exact_evidence_pairs = exact_evidence_pairs and str(entry.get("matrix_ship_id", "")) == matrix_id
	_check(exact_evidence_pairs, "current runtime view preserves the four evidence-backed matrix-to-runtime pairs")

	var halyard := by_runtime.get("halyard_new_design", {}) as Dictionary
	_check(
		not halyard.is_empty()
		and not halyard.has("matrix_ship_id")
		and bool(halyard.get("implemented", false))
		and str(halyard.get("evidence_status", "")) == "new"
		and (halyard.get("evidence_references", []) as Array).is_empty()
		and not bool(halyard.get("historical_claim", true))
		and str(halyard.get("implementation_label", "")) == "modern_interpretation",
		"Halyard is runtime-only NEW content with no matrix identity, evidence references, or historical claim"
	)


func _entries_by_runtime_id(entries: Array) -> Dictionary:
	var by_runtime := {}
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		var runtime_id := str(entry.get("runtime_ship_id", ""))
		if not runtime_id.is_empty():
			by_runtime[runtime_id] = entry
	return by_runtime


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _string_set_matches(expected: Array[String], actual: Array[String]) -> bool:
	return expected.size() == actual.size() \
		and _list_is_unique(expected) \
		and _list_is_unique(actual) \
		and _list_is_subset(expected, actual)


func _list_is_unique(values: Array[String]) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if seen.has(value):
			return false
		seen[value] = true
	return true


func _list_is_subset(required: Array[String], candidate: Array[String]) -> bool:
	for item in required:
		if not candidate.has(item):
			return false
	return true


func _set_is_subset(expected: Array[String], actual: Array[String]) -> bool:
	for item in expected:
		if not actual.has(item):
			return false
	return true


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


## True when any registered anchor on the source names the class, which is the
## minimum a name-to-model claim would need before it could be believed.
func _ledger_anchor_mentions(ledger: Dictionary, source_id: String, needle: String) -> bool:
	var source := _source_by_id(ledger, source_id)
	for anchor_variant in source.get("anchors", []) as Array:
		var anchor := anchor_variant as Dictionary
		if str(anchor.get("observation", "")).to_lower().contains(needle.to_lower()):
			return true
	return false


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
