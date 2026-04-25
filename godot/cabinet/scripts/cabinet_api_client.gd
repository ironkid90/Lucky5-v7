extends RefCounted
class_name CabinetApiClient

const FIXTURE_PATH := "res://fixtures/classic_snapshot.json"

func fetch_snapshot(machine_id: int) -> Dictionary:
	return _load_json(FIXTURE_PATH)

func load_classic_snapshot() -> Dictionary:
	return fetch_snapshot(1)

func emit_command(command_type: String, machine_id: int, session_id, expected_state_version: int, payload: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "v1",
		"command_id": _pseudo_uuid(),
		"command_type": command_type,
		"session_id": session_id,
		"machine_id": machine_id,
		"expected_state_version": expected_state_version,
		"idempotency_key": "%s-%s" % [command_type, Time.get_unix_time_from_system()],
		"payload": payload.duplicate(true),
		"timestamp": Time.get_datetime_string_from_system(true) + "Z"
	}

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func _pseudo_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var raw := ""
	for _index in range(32):
		raw += "%x" % rng.randi_range(0, 15)
	return "%s-%s-%s-%s-%s" % [
		raw.substr(0, 8),
		raw.substr(8, 4),
		raw.substr(12, 4),
		raw.substr(16, 4),
		raw.substr(20, 12)
	]
