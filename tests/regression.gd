extends SceneTree

var loader: Node
var failures: Array = []
var checks := 0
var seen: Array = []
var remove_id := -1

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func entry(id: String, dependencies: Array = [], priority: int = 0) -> Dictionary:
	return {"mod_id": id, "mod_name": id, "file_name": id + ".vmz", "full_path": id + ".vmz", "version": "1.0.0", "enabled": true, "priority": priority, "dependencies_required": dependencies, "dependencies_optional": [], "ext": "pck", "cfg": null, "profile_key": id}

func _initialize():
	call_deferred("run")

func run():
	var script = load("res://OrcLoader.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	loader = script.new()
	loader._has_loaded = true
	root.add_child(loader)
	loader.process_mode = Node.PROCESS_MODE_ALWAYS
	loader._boot_complete = true
	var framework := entry("framework", [], 99)
	var consumer := entry("consumer", [{"id": "framework", "raw": "framework"}], -99)
	var entries: Array[Dictionary] = [consumer, framework]
	check(loader._ordered_candidates(entries)[0] == framework, "dependency precedes priority")
	framework.enabled = false
	check(loader._ordered_candidates(entries).is_empty(), "disabled dependency blocks consumer")
	framework.enabled = true
	framework.dependencies_required = [{"id": "absent", "raw": "absent"}]
	check(loader._ordered_candidates(entries).is_empty(), "transitive blocked prerequisite")
	framework.dependencies_required = [{"id": "consumer", "raw": "consumer"}]
	check(loader._ordered_candidates(entries).is_empty(), "cycle blocked")
	framework.dependencies_required = []
	loader._ui_mod_entries = entries
	loader._running_configuration = loader._configuration_signature()
	check(not loader._has_pending_changes(), "initial loadout clean")
	consumer.enabled = false
	check(loader._has_pending_changes(), "toggle detected")
	consumer.enabled = true
	check(not loader._has_pending_changes(), "reverted toggle clean")
	loader._mods_hide_disabled = true
	check(not loader._has_pending_changes(), "display preference clean")
	var cfg := ConfigFile.new()
	cfg.set_value("test", "value", 1)
	check(loader._save_config_recoverably(cfg, "user://atomic.cfg") == OK, "initial recoverable write")
	cfg.set_value("test", "value", 2)
	check(loader._save_config_recoverably(cfg, "user://atomic.cfg") == OK, "replacement write")
	var old := ConfigFile.new()
	old.load("user://atomic.cfg.bak")
	check(old.get_value("test", "value") == 1, "backup preserves original")
	check(loader._replace_file_recoverably(ProjectSettings.globalize_path("user://atomic.cfg"), ProjectSettings.globalize_path("user://absent.tmp")) != OK, "failed replacement reported")
	old.load("user://atomic.cfg")
	check(old.get_value("test", "value") == 2, "failed replacement restores original")
	loader.hook("test-pre", mutate)
	remove_id = loader.hook("test-pre", second)
	loader._dispatch("test-pre", [])
	check(seen == ["first", "second"], "dispatch retains snapshot during unhook")
	seen.clear()
	loader._dispatch("test-pre", [])
	check(seen == ["first"], "next dispatch sees removal")
	loader.show_mod_ui()
	await process_frame
	check(is_instance_valid(loader._ui_window), "menu opens")
	loader._request_ui_close()
	await process_frame
	check(loader._ui_window == null, "unchanged close returns without restart")
	consumer.enabled = false
	loader.show_mod_ui()
	await process_frame
	loader._request_ui_close()
	check(is_instance_valid(loader._close_dialog), "changed close warns")
	loader._close_dialog.custom_action.emit("later")
	await process_frame
	check(loader._ui_window == null and loader._has_pending_changes(), "deferred changes survive close")
	loader.show_mod_ui()
	await process_frame
	check(loader._ui_launch_btn.text == "Apply and Restart", "reopen shows pending restart")
	consumer.enabled = true
	loader.refresh_launch_button_label()
	check(loader._ui_launch_btn.text == "Back to Game", "reversion clears restart label")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	loader._input(escape)
	await process_frame
	check(loader._ui_window == null, "Escape closes unchanged menu")
	check(loader._parse_pck_file_list("res://embedded.exe") == PackedStringArray(["battle/battle.gd"]), "embedded v3 PCK directory")
	check(loader._zip_scan_sizes("res://valid.vmz").size() == 2, "bounded ZIP accepts normal archive")
	check(loader._zip_scan_sizes("res://oversized.vmz").is_empty(), "oversized ZIP rejected before decompression")
	var findings: Array = loader.scan_mod("res://large.vmz", "vmz")
	check(findings.size() == 1 and findings[0].rule == "incomplete_scan", "large text reported incomplete")
	check(loader.scan_mod("res://valid.vmz", "vmz").is_empty(), "valid script scan")
	check(loader._scan_cache.size() >= 2, "scan results cached")
	loader._scan_cache.clear()
	check(loader.scan_mod("res://large.vmz", "vmz").size() == 1, "persistent scan cache preserves incomplete status")
	loader._active_profile = "Custom"
	loader._save_ui_config()
	loader._active_profile = "Default"
	loader._load_ui_config()
	check(loader._active_profile == "Custom", "active profile restored")
	check(loader.register_mod_setting("fixture", "speed", "Speed", [1, 2, 3], 1, setting_changed), "mod setting registered")
	check(not loader.register_mod_setting("fixture", "bad", "Bad", [], 1, setting_changed), "invalid setting rejected")
	var f := FileAccess.open("user://save_0.save", FileAccess.WRITE)
	f.store_string("fixture save")
	f.close()
	loader._snapshot_enabled = true
	check(loader._snapshot_before_launch(), "save snapshot succeeds")
	var snapshots := DirAccess.get_directories_at("user://orckit_save_snapshots")
	check(snapshots.size() == 1, "one snapshot created")
	check(FileAccess.get_file_as_string("user://orckit_save_snapshots/" + snapshots[0] + "/save_0.save") == "fixture save", "snapshot content verified")
	check(FileAccess.get_file_as_string("user://save_0.save") == "fixture save", "snapshot leaves source unchanged")
	paused = true
	loader._running_configuration = loader._configuration_signature()
	loader.show_mod_ui()
	await process_frame
	loader._input(escape)
	await process_frame
	check(loader._ui_window == null and paused, "Escape closes while preserving pause")
	paused = false
	consumer.enabled = false
	loader.show_mod_ui()
	await process_frame
	loader._request_ui_close()
	loader._input(escape)
	check(loader._ui_window != null, "nested dialog prevents double Escape close")
	loader._close_dialog.canceled.emit()
	await process_frame
	check(loader._ui_window != null, "keep editing leaves menu open")
	consumer.enabled = true
	loader._request_ui_close()
	await process_frame
	check(loader._ui_window == null, "reverted changes close after cancelling warning")
	consumer.risk_level = 2
	loader.show_mod_ui()
	await process_frame
	loader._request_ui_launch()
	await process_frame
	check(loader._ui_window == null, "unchanged Back to Game does not request security confirmation")
	var automatic := entry("automatic")
	automatic.full_path = "res://valid.vmz"
	var automatic_entries: Array[Dictionary] = [automatic]
	loader._ui_mod_entries = automatic_entries
	loader._filescope_mounted = {"res://valid.vmz": true}
	var paths := PackedStringArray(["res://valid.vmz"])
	check(loader._write_pass_state(paths, "test") == OK, "startup receipt can be prepared")
	check(not loader._can_resume_saved_loadout(), "uncompleted setup cannot autostart")
	loader._mark_startup_ready()
	check(loader._can_resume_saved_loadout(), "unchanged successful loadout autostarts")
	loader._automatic_startup = false
	check(not loader._can_resume_saved_loadout(), "automatic startup preference respected")
	loader._automatic_startup = true
	automatic.enabled = false
	check(not loader._can_resume_saved_loadout(), "changed enabled selection requires setup")
	automatic.enabled = true
	automatic.ext = "folder"
	check(not loader._can_resume_saved_loadout(), "editable folder mods require setup")
	automatic.ext = "pck"
	loader._filescope_mounted.clear()
	check(not loader._can_resume_saved_loadout(), "missing early mount requires setup")
	loader._filescope_mounted = {"res://valid.vmz": true}
	var dirty := FileAccess.open(loader.PASS2_DIRTY_PATH, FileAccess.WRITE)
	dirty.store_string("interrupted")
	dirty.close()
	check(not loader._can_resume_saved_loadout(), "interrupted boot cannot autostart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(loader.PASS2_DIRTY_PATH))
	var receipt := ConfigFile.new()
	receipt.load(loader.PASS_STATE_PATH)
	receipt.set_value("state", "archive_hashes", {"res://valid.vmz": "changed"})
	receipt.save(loader.PASS_STATE_PATH)
	check(not loader._can_resume_saved_loadout(), "changed package fingerprint requires setup")
	loader._write_pass_state(paths, "test")
	loader._mark_startup_ready()
	receipt.load(loader.PASS_STATE_PATH)
	receipt.set_value("state", "hook_pack_path", "user://missing-hooks.zip")
	receipt.set_value("state", "hook_pack_hash", "missing")
	receipt.save(loader.PASS_STATE_PATH)
	check(not loader._can_resume_saved_loadout(), "missing hook cache requires setup")
	loader._filescope_mounted = {"first": true, "second": true}
	check(loader._filescope_mounts_differ_from(PackedStringArray(["second", "first"])), "mount order changes require restart")
	loader.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func mutate():
	seen.append("first")
	loader.unhook(remove_id)

func second():
	seen.append("second")

func setting_changed(_value):
	pass
