extends Node
var started := false
var clicked := false
var deadline := Time.get_ticks_msec() + 45000

func _enter_tree():
	if OS.has_feature("steam") or not ProjectSettings.globalize_path("user://").contains("/work/startup-integration-userdata/"):
		get_tree().quit(10)
		return
	var launches: Array = []
	if FileAccess.file_exists("user://startup-launches.json"):
		launches = JSON.parse_string(FileAccess.get_file_as_string("user://startup-launches.json"))
	launches.append(OS.get_process_id())
	var file := FileAccess.open("user://startup-launches.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(launches))
	file.close()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		get_tree().quit(11)
	var kit = get_node_or_null("/root/OrcKit")
	if kit == null:
		return
	if not kit._is_ready:
		if is_instance_valid(kit._ui_launch_btn) and not clicked:
			clicked = true
			var count := 0
			if FileAccess.file_exists("user://startup-menu-count.txt"):
				count = int(FileAccess.get_file_as_string("user://startup-menu-count.txt"))
			var file := FileAccess.open("user://startup-menu-count.txt", FileAccess.WRITE)
			file.store_string(str(count + 1))
			file.close()
			kit._ui_launch_btn.pressed.emit.call_deferred()
		return
	if not started:
		started = true
		finish.call_deferred(kit)

func finish(kit):
	await get_tree().create_timer(1.0, true, false, true).timeout
	var menus := int(FileAccess.get_file_as_string("user://startup-menu-count.txt")) if FileAccess.file_exists("user://startup-menu-count.txt") else 0
	var result := {
		"processes": JSON.parse_string(FileAccess.get_file_as_string("user://startup-launches.json")),
		"menus": menus,
		"speed_mod_loaded": get_node_or_null("/root/OrcSpeedControls") != null,
		"startup_receipt_valid": kit._can_resume_saved_loadout(),
		"save_hash": FileAccess.get_sha256("user://save_0.save")
	}
	var file := FileAccess.open("user://startup-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	get_tree().quit()

