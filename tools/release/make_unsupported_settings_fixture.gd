extends SceneTree

## Produce the dedicated release-route fixture with the production store's JSON
## canonicalization and checksum. This never loads Main or changes live settings.
const Store := preload("res://scripts/persistence/user_data_store.gd")
const PAYLOAD := {
	"runtime_settings": {"schema_version": 12, "values": {}},
	"tutorial_prompts_seen": {
		"schema_version": 1, "seen_ids": ["cinder_reach_checkpoint_route"],
	},
	"solo_safe_recovery": {
		"location": "mudds_home_berth", "mode": "on_foot",
		"craft_id": "arrow_provisional", "berth_id": "arrow_recon_berth",
	},
	"unrelated_future_test": {"label": "KEEP"},
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--output" or not args[1].is_absolute_path():
		_fail("Use -- --output ABSOLUTE_NEW_FILE")
		return
	var output := args[1]
	for suffix: String in ["", ".tmp", ".bak", ".bak.1", ".bak.2", ".bak.3", ".recovery"]:
		if FileAccess.file_exists(output + suffix) or DirAccess.dir_exists_absolute(output + suffix):
			_fail("Fixture destination or sibling already exists")
			return
	var store := Store.new(output)
	var loaded: Dictionary = store.load()
	if not loaded.get("accepted", false) or loaded.get("reason") != &"empty":
		_fail("Fixture store did not begin empty")
		return
	var committed: Dictionary = store.commit(PAYLOAD, 0, "nested-settings-fixture")
	if not committed.get("accepted", false) or store.get_generation() != 1:
		_fail("Production fixture commit failed")
		return
	if not OS.has_feature("windows") and FileAccess.set_unix_permissions(output, 384) != OK:
		_fail("Fixture mode could not be set to 0600")
		return
	var reopened := Store.new(output)
	var verified: Dictionary = reopened.load_read_only()
	if not verified.get("accepted", false) or reopened.get_snapshot() != PAYLOAD:
		_fail("Production fixture readback failed")
		return
	print("UNSUPPORTED_SETTINGS_FIXTURE_OK ", JSON.stringify({
		"bytes": FileAccess.get_file_as_bytes(output).size(),
		"sha256": FileAccess.get_sha256(output), "generation": reopened.get_generation(),
	}))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
