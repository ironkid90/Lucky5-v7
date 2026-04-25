extends RefCounted
class_name CabinetStateStore

signal snapshot_applied(snapshot: Dictionary)

var snapshot: Dictionary = {}

func apply_snapshot(next_snapshot: Dictionary) -> Dictionary:
	snapshot = next_snapshot.duplicate(true)
	snapshot_applied.emit(snapshot)
	return snapshot
