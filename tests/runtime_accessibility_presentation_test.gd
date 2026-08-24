extends SceneTree

const Contract := preload("res://scripts/ui/runtime_accessibility_presentation.gd")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const AudioPreset := preload("res://scripts/audio/audio_accessibility_preset.gd")

class MalformedRuntimeSettings extends RuntimeSettings:
	func get_accessibility_descriptor() -> Dictionary:
		var malformed := super.get_accessibility_descriptor()
		malformed["colorblind_palette_id"] = &"tritanopia"
		return malformed


var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var contract := Contract.new()
	_check(bool(contract.audit().valid), "composed accessibility policies start valid")
	_check(bool(contract.audit().presentation_only), "runtime adapter publishes a presentation-only boundary")
	var configured := contract.configure({
		"visual": {"colour_safe_cues": true, "reduced_flash": true, "reduced_motion": true, "ui_scale": 1.25},
		"captions": {"verbosity": &"all", "high_contrast": true},
		"audio": {"subtitle_verbosity": 2},
	})
	_check(bool(configured.accepted) and int(configured.revision) == 1, "visual, caption and audio policies apply atomically")
	var cue := contract.resolve_cue({
		"cue_id": &"reactor_warning",
		"visual_category": &"danger",
		"caption_category": &"system",
		"audible": false,
		"key_cue": true,
		"priority": 90,
		"text": "",
		"bus": &"UI",
	})
	_check(bool(cue.accepted), "an observed cue produces a composed presentation result")
	_check(bool(cue.visual.shape_cue != &"none") and is_zero_approx(float(cue.visual.flash_strength)) and is_zero_approx(float(cue.visual.motion_strength)), "visual reduced-motion and colour-safe alternatives survive composition")
	_check(bool(cue.caption.accepted) and bool(cue.caption.inaudible_fallback) and cue.caption.text == "[inaudible]", "inaudible cues receive a textual caption fallback")
	_check(not bool(cue.gameplay_authority) and not bool(cue.audio_authority) and not bool(cue.caption_authority), "composed decisions grant no runtime authority")
	var fitted := contract.fit_prompt(Vector2(5120, 1440), Vector2(520, 88), &"bottom_center")
	_check(bool(fitted.valid) and not bool(fitted.clipped) and fitted.safe_rect.encloses(fitted.rect), "32:9 prompts fit the shared scaled safe area")
	var prompts := contract.get_server_browser_prompts()
	_check(prompts.refresh == "Refresh server list" and prompts.join_hint is String and not str(prompts.empty_results).is_empty(), "server-browser prompts remain textual and actionable")
	var before := contract.get_snapshot()
	var rejected := contract.configure({"visual": {"ui_scale": 99.0}, "audio": {"bus_ceilings": {&"NotABus": 0.0}}})
	_check(not bool(rejected.accepted) and int(contract.get_snapshot().revision) == int(before.revision), "malformed cross-policy changes reject without advancing the runtime revision")
	_test_active_settings_status(contract)
	_finish()


func _test_active_settings_status(contract: RefCounted) -> void:
	var settings := Settings.new()
	settings.captions_enabled = true
	settings.reduced_flash = true
	settings.reduced_motion = true
	settings.ui_scale = 1.35
	settings.colorblind_palette = Settings.ColorblindPalette.TRITANOPIA
	var settings_before := settings.to_dictionary()
	var attached: Dictionary = contract.attach(settings, int(contract.get_snapshot().revision))
	var status := attached.snapshot.status_confirmation as Dictionary
	_check(
		bool(attached.accepted) and bool(attached.snapshot.attached)
			and status.status_text == "ACCESSIBILITY OPTIONS // ACTIVE",
		"validated RuntimeSettings produce an immediate active accessibility confirmation"
	)
	_check(
		bool(status.captions_enabled) and bool(status.reduced_flash) and bool(status.reduced_motion)
			and is_equal_approx(float(status.ui_scale), 1.35)
			and is_equal_approx(float(status.text_scale), 1.35)
			and status.colorblind_palette_id == &"tritanopia",
		"the confirmation covers the actual caption, flash, motion, UI/text scale and colour-alternative fields"
	)
	var reconciled: Dictionary = contract.get_snapshot()
	var caption_profile := reconciled.captions.profile as Dictionary
	_check(
		is_equal_approx(float(reconciled.visual.ui_scale), 1.35)
			and bool(reconciled.visual.reduced_flash)
			and bool(reconciled.visual.reduced_motion)
			and bool(reconciled.visual.colour_safe_cues)
			and bool(caption_profile.captions_enabled)
			and bool(caption_profile.reduced_flash)
			and bool(caption_profile.reduced_motion)
			and int(reconciled.audio.subtitle_verbosity) == AudioPreset.SubtitleVerbosity.ALL_CUES,
		"attachment reconciles every public presentation policy to the same active settings descriptor"
	)
	_check(
		status.rows.size() == 5
			and status.rows[0].text == "CAPTIONS // ON"
			and status.rows[1].text == "REDUCED FLASH // ON"
			and status.rows[2].text == "REDUCED MOTION // ON"
			and status.rows[3].text == "UI / TEXT SCALE // 135%"
			and status.rows[4].text == "COLOUR ALTERNATIVE // TRITANOPIA ALTERNATIVE",
		"every active choice is confirmed in player-readable text rather than colour alone"
	)
	_check(
		bool(status.color_independent) and bool(status.uses_text_labels)
			and not bool(status.focusable) and not bool(status.steals_focus)
			and bool(status.safe_area_owned_by_caller),
		"the status card preserves focus and the caller-owned safe-area contract"
	)
	_check(
		settings.to_dictionary() == settings_before
			and not bool(attached.settings_authority) and not bool(attached.input_authority)
			and not bool(attached.camera_authority) and not bool(attached.audio_authority),
		"reading the active preset cannot mutate settings, input, camera or audio authority"
	)
	status.rows[0].text = "tampered"
	status.announcement_text = "tampered"
	_check(
		contract.get_snapshot().status_confirmation.rows[0].text == "CAPTIONS // ON"
			and not str(contract.get_snapshot().status_confirmation.announcement_text).contains("tampered"),
		"returned status cards are deeply detached from the retained presentation"
	)
	var attached_revision := int(contract.get_snapshot().revision)
	var invalid_replacement: Dictionary = contract.attach(MalformedRuntimeSettings.new(), attached_revision)
	_check(
		not bool(invalid_replacement.accepted) and invalid_replacement.reason == &"invalid_colour_alternative"
			and int(contract.get_snapshot().revision) == attached_revision
			and contract.get_snapshot().status_confirmation.colorblind_palette_id == &"tritanopia",
		"a mismatched palette value/ID rejects atomically without clearing the live settings status"
	)
	settings.captions_enabled = false
	var live: Dictionary = contract.get_snapshot()
	_check(
		int(live.revision) == attached_revision + 1
			and live.status_confirmation.rows[0].text == "CAPTIONS // OFF"
			and not bool(live.captions.profile.captions_enabled)
			and int(live.audio.subtitle_verbosity) == AudioPreset.SubtitleVerbosity.OFF,
		"a supported live RuntimeSettings change repaints the textual confirmation immediately"
	)
	var disabled_cue: Dictionary = contract.resolve_cue({
		"cue_id": &"captions_disabled",
		"visual_category": &"info",
		"caption_category": &"system",
		"audible": false,
		"key_cue": true,
		"text": "Caption disabled.",
		"bus": &"UI",
	})
	_check(
		bool(disabled_cue.accepted)
			and not bool(disabled_cue.visual.show_caption)
			and not bool(disabled_cue.audio.show_subtitle)
			and not bool(disabled_cue.caption.get("accepted", false)),
		"cue output cannot contradict a captions-off status across visual, caption and audio policies"
	)
	var live_revision := int(live.revision)
	settings.master_volume = 0.25
	_check(
		int(contract.get_snapshot().revision) == live_revision,
		"unrelated audio settings do not repaint or grant audio authority to the status presenter"
	)
	var stale_detach: Dictionary = contract.detach(live_revision - 1)
	_check(
		not bool(stale_detach.accepted) and stale_detach.reason == &"stale_revision"
			and bool(contract.get_snapshot().attached),
		"an inexact revision cannot detach the active presentation"
	)
	var detached: Dictionary = contract.detach(live_revision)
	var detached_revision := int(detached.revision)
	settings.reduced_flash = false
	_check(
		bool(detached.accepted) and not bool(detached.snapshot.attached)
			and detached.snapshot.status_confirmation.is_empty()
			and int(contract.get_snapshot().revision) == detached_revision,
		"detach clears the signal and retained card so the old settings owner cannot repaint it"
	)
	var replacement := Settings.new()
	replacement.ui_scale = 1.1
	replacement.colorblind_palette = Settings.ColorblindPalette.PROTANOPIA
	var reused: Dictionary = contract.attach(replacement, detached_revision)
	_check(
		bool(reused.accepted) and reused.snapshot.status_confirmation.rows[3].text == "UI / TEXT SCALE // 110%"
			and reused.snapshot.status_confirmation.colorblind_palette_id == &"protanopia"
			and is_equal_approx(float(reused.snapshot.visual.ui_scale), 1.1)
			and bool(reused.snapshot.visual.colour_safe_cues)
			and not bool(reused.snapshot.captions.profile.captions_enabled)
			and int(reused.snapshot.audio.subtitle_verbosity) == AudioPreset.SubtitleVerbosity.OFF,
		"the detached presenter is reusable at its exact revision without leaking the previous preset"
	)
	var configured: Dictionary = contract.configure({
		"visual": {"ui_scale": 0.75, "reduced_motion": true, "colour_safe_cues": false},
		"captions": {"captions_enabled": true},
		"audio": {"subtitle_verbosity": 2},
	})
	var settings_owned := configured.snapshot as Dictionary
	_check(
		bool(configured.accepted)
			and is_equal_approx(float(settings_owned.visual.ui_scale), 1.1)
			and not bool(settings_owned.visual.reduced_motion)
			and bool(settings_owned.visual.colour_safe_cues)
			and not bool(settings_owned.captions.profile.captions_enabled)
			and int(settings_owned.audio.subtitle_verbosity) == AudioPreset.SubtitleVerbosity.OFF
			and is_equal_approx(float(settings_owned.status_confirmation.ui_scale), 1.1),
		"attached settings remain the shared-field authority across later public configuration"
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RUNTIME_ACCESSIBILITY_PRESENTATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("RUNTIME_ACCESSIBILITY_PRESENTATION_TEST_FAILED: %d/%d failed" % [_failures.size(), _assertions])
		quit(1)
