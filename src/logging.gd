
func _log_info(msg: String) -> void:
	var line := "[OrcKit][Info] " + msg
	print(line)
	_report_lines.append(line)

func _log_warning(msg: String) -> void:
	var line := "[OrcKit][Warning] " + msg
	push_warning(line)
	_report_lines.append(line)

func _log_critical(msg: String) -> void:
	var line := "[OrcKit][Critical] " + msg
	push_error(line)
	_report_lines.append(line)

func _log_debug(msg: String) -> void:
	if not _developer_mode:
		return
	var line := "[OrcKit][Debug] " + msg
	print(line)
	_report_lines.append(line)
func _record_timing(phase: String, started: int) -> void:
	if not _diagnostics_enabled:
		return
	var elapsed := Time.get_ticks_usec() - started
	_performance[phase] = int(_performance.get(phase, 0)) + elapsed
	if phase.begins_with("hook:"):
		return
	_log_info("[Performance] %s: %.2f ms (total %.2f ms)" % [phase, elapsed / 1000.0, _performance[phase] / 1000.0])
