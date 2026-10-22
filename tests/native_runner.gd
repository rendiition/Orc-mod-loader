extends Node
var started := false
var launch_pressed := false
var start_time := Time.get_ticks_msec()
var failures: Array = []
var checks := 0

func _enter_tree():
	if OS.has_feature("steam") or not ProjectSettings.globalize_path("user://").contains("/work/loader-integration-userdata/"):
		get_tree().quit(10)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func _process(_delta):
	if Time.get_ticks_msec() - start_time > 60000:
		get_tree().quit(11)
	var loader = get_node_or_null("/root/OrcKit")
	if loader == null:
		return
	if not loader._is_ready:
		if is_instance_valid(loader._ui_launch_btn) and not launch_pressed:
			launch_pressed = true
			loader._ui_launch_btn.pressed.emit.call_deferred()
		return
	if not started:
		started = true
		run.call_deferred(loader)

func wait_real(seconds):
	await get_tree().create_timer(seconds, true, false, true).timeout

func run(loader):
	get_tree().root.gui_embed_subwindows = true
	await wait_real(2)
	check(loader.MODLOADER_VERSION == "1.2.0", "new loader running")
	check(loader._script_discovery_source == "native-test.exe", "native embedded script discovery")
	check(loader._all_game_script_paths.has("res://battle/battle.gd"), "battle script discovered")
	check(get_node_or_null("/root/OrcSpeedControls") != null, "existing speed mod loads")
	var save_hash := FileAccess.get_sha256("user://save_0.save")
	var paused := get_tree().paused
	loader.reopen_mod_ui()
	await wait_real(0.2)
	check(loader._ui_launch_btn.text == "Back to Game", "unchanged button label")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://loader-preview.png")
	var tabs: Array = loader._ui_window.find_children("", "TabContainer", true, false)
	tabs[0].current_tab = 1
	await wait_real(0.2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://loader-settings.png")
	tabs[0].current_tab = 0
	loader._request_ui_close()
	await wait_real(0.2)
	check(loader._ui_window == null, "unchanged closes without restart")
	check(get_tree().paused == paused, "original pause retained")
	loader.reopen_mod_ui()
	await wait_real(0.2)
	var entry: Dictionary = loader._ui_mod_entries[0]
	entry.enabled = false
	loader._save_ui_config()
	loader._request_ui_close()
	check(is_instance_valid(loader._close_dialog), "changed close warning")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://loader-warning.png")
	loader._close_dialog.custom_action.emit("later")
	await wait_real(0.2)
	check(loader._ui_window == null and loader._has_pending_changes(), "save later closes and retains pending")
	check(get_node_or_null("/root/OrcSpeedControls") != null, "current mod remains running")
	loader.reopen_mod_ui()
	await wait_real(0.2)
	check(loader._ui_launch_btn.text == "Apply and Restart", "reopen retains warning")
	entry.enabled = true
	loader._save_ui_config()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await wait_real(0.3)
	check(loader._ui_window == null, "real Escape input closes reverted menu")
	check(FileAccess.get_sha256("user://save_0.save") == save_hash, "menu operations leave save unchanged")
	var result := {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string}
	var file := FileAccess.open("user://loader-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("LOADER RESULTS: ", JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)

