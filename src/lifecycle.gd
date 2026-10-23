
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _has_loaded:
		return
	_has_loaded = true
	if _is_modloader_disabled():
		print("[OrcKit] disabled via sentinel file -- sitting idle")
		return
	await get_tree().process_frame
	_compile_regex()
	var is_pass_2 := "--modloader-restart" in OS.get_cmdline_user_args()
	if is_pass_2:
		await _run_pass_2()
	else:
		await _run_pass_1()

func _modloader_restart(clean_pass1: bool) -> void:
	var args: Array = []
	if clean_pass1:
		for a in OS.get_cmdline_args():
			if a != "--modloader-restart":
				args.append(a)
	else:
		args = Array(OS.get_cmdline_args())
	_preserve_engine_driver_args(args)
	if not clean_pass1:
		args.append_array(["--", "--modloader-restart"])
	OS.set_restart_on_exit(true, args)
	get_tree().quit()

func _preserve_engine_driver_args(args: Array) -> void:
	if not args.has("--rendering-driver"):
		var driver := RenderingServer.get_current_rendering_driver_name()
		if not driver.is_empty():
			args.append("--rendering-driver")
			args.append(driver)
	if not args.has("--rendering-method"):
		var method := RenderingServer.get_current_rendering_method()
		if not method.is_empty():
			args.append("--rendering-method")
			args.append(method)

func reopen_mod_ui() -> void:
	if _ui_window != null:
		return
	var action := await show_mod_ui()
	if action == "restart":
		_log_info("[OrcKit] Post-boot mod changes detected -- restarting")
		_modloader_restart(true)

func _run_pass_1() -> void:
	_log_info("OrcKit v" + MODLOADER_VERSION)
	var interrupted_startup := FileAccess.file_exists(HEARTBEAT_PATH)
	_check_crash_recovery()
	_check_safe_mode()
	_compile_regex()
	_build_class_name_lookup()
	_enumerate_game_scripts()
	_load_developer_mode_setting()
	_ui_mod_entries = await _discover_with_progress()
	_clean_stale_cache()
	_load_ui_config()
	if not interrupted_startup and _can_resume_saved_loadout():
		_log_info("Saved loadout verified -- loading enabled mods without a startup menu or restart")
		await _run_pass_2(true)
		return
	await show_mod_ui()
	_save_ui_config()

	load_all_mods()
	_apply_script_overrides()

	var sections := _build_autoload_sections()
	var archive_paths := _collect_enabled_archive_paths()
	if _filescope_mounts_differ_from(archive_paths):
		_log_info("[OrcKit] Enabled mod set changed since static mount -- cleaning stale mounted mods and restarting")
		_reset_cached_mod_state_for_restart()
		_modloader_restart(true)
		return

	var new_hash := _compute_state_hash(archive_paths, sections.prepend)
	var old_hash := ""
	var state_cfg := ConfigFile.new()
	if state_cfg.load(PASS_STATE_PATH) == OK:
		old_hash = state_cfg.get_value("state", "mods_hash", "")

	if new_hash == old_hash and not new_hash.is_empty():
		_log_info("Mod state unchanged -- skipping restart")
		await _finish_with_existing_mounts()
		return


	if archive_paths.size() > 0:
		_log_info("Preparing two-pass restart -- %d archive(s)" % archive_paths.size())
		if sections.prepend.size() > 0:
			_log_info("  %d early autoload(s) written after OrcKit in [autoload]" % sections.prepend.size())
		_register_orcmodlib_meta()
		_generate_hook_pack(true)
		_write_heartbeat()
		var err := _write_override_cfg(sections.prepend)
		if err != OK:
			_log_critical("Failed to write override.cfg (error %d) -- single-pass fallback" % err)
			await _finish_single_pass()
			return
		if _write_pass_state(archive_paths, new_hash) != OK:
			await _finish_single_pass()
			return
		_modloader_restart(false)
		return

	if FileAccess.file_exists(PASS_STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PASS_STATE_PATH))
		_restore_clean_override_cfg()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(HOOK_PACK_DIR)):
		_static_wipe_hook_cache()
		_log_info("[Hooks] Cleaned up unused hook artifacts")
	await _finish_single_pass()

func _filescope_mounts_differ_from(archive_paths: PackedStringArray) -> bool:
	if _filescope_mounted.is_empty():
		return false
	var mounted: Array[String] = []
	for p in _filescope_mounted.keys():
		mounted.append(String(p))
	var desired: Array[String] = []
	for p in archive_paths:
		desired.append(String(p))
	if mounted.size() != desired.size():
		return true
	for i in mounted.size():
		if mounted[i] != desired[i]:
			return true
	return false

func _reset_cached_mod_state_for_restart() -> void:
	if FileAccess.file_exists(PASS_STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PASS_STATE_PATH))
	if FileAccess.file_exists(PASS2_DIRTY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PASS2_DIRTY_PATH))
	_restore_clean_override_cfg()
	_static_wipe_hook_cache()
	_delete_heartbeat()

func _finish_with_existing_mounts() -> void:
	_boot_complete = true
	_register_orcmodlib_meta()
	_generate_hook_pack()
	for entry in _pending_autoloads:
		if get_tree().root.has_node(entry["name"]):
			_log_info("  Autoload '%s' already in tree -- skipped" % entry["name"])
			continue
		_instantiate_autoload(entry["mod_name"], entry["name"], entry["path"])
	if _developer_mode:
		_log_override_timing_warnings()
		_print_conflict_summary()
		_write_conflict_report()
	_emit_frameworks_ready()
	_delete_heartbeat()
	if not _filescope_mounted.is_empty() or not _archive_file_sets.is_empty() or _pending_autoloads.size() > 0:
		var err := get_tree().reload_current_scene()
		if err != OK:
			_log_critical("reload_current_scene() failed with error " + str(err))
			return
	_mark_startup_ready()

func _finish_single_pass() -> void:
	_boot_complete = true
	_register_orcmodlib_meta()
	_generate_hook_pack()
	for entry in _pending_autoloads:
		_instantiate_autoload(entry["mod_name"], entry["name"], entry["path"])
	if _developer_mode:
		_log_override_timing_warnings()
		_print_conflict_summary()
		_write_conflict_report()
	_emit_frameworks_ready()
	_delete_heartbeat()
	if not _archive_file_sets.is_empty() or _pending_autoloads.size() > 0:
		var err := get_tree().reload_current_scene()
		if err != OK:
			_log_critical("reload_current_scene() failed with error " + str(err))
			return



func _run_pass_2(discovery_ready: bool = false) -> void:
	_boot_complete = true
	_log_info("Pass 2 -- %d archive(s) mounted at file-scope" % _filescope_mounted.size())
	var _dirty_f := FileAccess.open(PASS2_DIRTY_PATH, FileAccess.WRITE)
	if _dirty_f:
		_dirty_f.store_string(str(Time.get_unix_time_from_system()))
		_dirty_f.close()
	var _pass_cfg := ConfigFile.new()
	if _pass_cfg.load(PASS_STATE_PATH) == OK:
		var saved_overrides: Array = _pass_cfg.get_value("state", "script_overrides", [])
		for entry in saved_overrides:
			if entry is Dictionary and entry.has("vanilla_path") and entry.has("mod_script_path"):
				_pending_script_overrides.append(entry)
			else:
				_log_warning("[Overrides] Malformed entry in pass state -- skipped")
	_apply_script_overrides()
	_clear_restart_counter()
	if not discovery_ready:
		_compile_regex()
		_build_class_name_lookup()
		_enumerate_game_scripts()
		_load_developer_mode_setting()
		_ui_mod_entries = await _discover_with_progress()
		_load_ui_config()

	load_all_mods("Pass 2")
	_register_orcmodlib_meta()
	_generate_hook_pack()
	for entry in _pending_autoloads:
		if get_tree().root.has_node(entry["name"]):
			_log_info("  Autoload '%s' already in tree -- skipped" % entry["name"])
			continue
		_instantiate_autoload(entry["mod_name"], entry["name"], entry["path"])

	if _developer_mode:
		_log_override_timing_warnings()
		_print_conflict_summary()
		_write_conflict_report()
	_emit_frameworks_ready()
	_delete_heartbeat()
	if not _filescope_mounted.is_empty() or not _archive_file_sets.is_empty() or _pending_autoloads.size() > 0:
		var err := get_tree().reload_current_scene()
		if err != OK:
			_log_critical("reload_current_scene() failed with error " + str(err))
			return
	_mark_startup_ready()
	if FileAccess.file_exists(PASS2_DIRTY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PASS2_DIRTY_PATH))

# Only unchanged, successfully prepared archives can bypass startup UI.
# Folder mods remain in the setup path because their contents may change live.
func _can_resume_saved_loadout() -> bool:
	if not _automatic_startup or "--modloader-menu" in OS.get_cmdline_user_args():
		return false
	if FileAccess.file_exists(PASS2_DIRTY_PATH) or FileAccess.file_exists(HEARTBEAT_PATH):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(PASS_STATE_PATH) != OK or not bool(cfg.get_value("state", "startup_ready", false)):
		return false
	if str(cfg.get_value("state", "loadout_signature", "")) != _configuration_signature():
		return false
	if str(cfg.get_value("state", "game_hash", "")) != FileAccess.get_sha256(OS.get_executable_path()) or str(cfg.get_value("state", "loader_hash", "")) != FileAccess.get_sha256(MODLOADER_RES_PATH):
		return false
	var candidates := _ordered_candidates(_ui_mod_entries)
	var desired := PackedStringArray()
	var hashes: Dictionary = cfg.get_value("state", "archive_hashes", {})
	for entry in _ui_mod_entries:
		if entry.get("enabled", false) and entry.get("dependency_blocked", false):
			return false
	for entry in candidates:
		if entry["ext"] == "folder":
			return false
		var path := str(entry["full_path"])
		if not FileAccess.file_exists(path) or hashes.get(path, "") != FileAccess.get_sha256(path):
			return false
		desired.append(path)
	var saved: PackedStringArray = cfg.get_value("state", "archive_paths", PackedStringArray())
	if desired.is_empty() or saved != desired or _filescope_mounted.size() != desired.size() or _filescope_mounts_differ_from(desired):
		return false
	var hook_path := str(cfg.get_value("state", "hook_pack_path", ""))
	if not hook_path.is_empty():
		if not FileAccess.file_exists(hook_path) or str(cfg.get_value("state", "hook_pack_hash", "")) != FileAccess.get_sha256(hook_path):
			return false
	return true

func _mark_startup_ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PASS_STATE_PATH) != OK:
		return
	cfg.set_value("state", "startup_ready", true)
	cfg.set_value("state", "loadout_signature", _configuration_signature())
	var hook_path := str(cfg.get_value("state", "hook_pack_path", ""))
	cfg.set_value("state", "hook_pack_hash", FileAccess.get_sha256(hook_path) if not hook_path.is_empty() else "")
	if _save_config_recoverably(cfg, PASS_STATE_PATH) != OK:
		_log_warning("Could not record successful startup; next launch will use the setup menu")
