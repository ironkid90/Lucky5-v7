extends RefCounted
class_name CabinetControls

signal command_requested(command_type: String, payload: Dictionary)

func emit_command(command_type: String, payload: Dictionary = {}) -> void:
	command_requested.emit(command_type, payload.duplicate(true))
