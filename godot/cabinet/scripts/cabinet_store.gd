extends RefCounted
class_name CabinetStore

var snapshot: Dictionary = {}
var button_state: Dictionary = {}
var last_transport_error: String = ""
var local_connected: bool = false

const BUTTON_ID_ALIASES := {
	"deal": "deal_draw",
	"cancel": "cancel_hold"
}

func apply_snapshot(next_snapshot: Dictionary, force: bool = false) -> bool:
	if next_snapshot.is_empty():
		return false
	var normalized := _normalize_snapshot(next_snapshot)
	var incoming_version: int = int(normalized.get("state_version", 0))
	var current_version: int = int(snapshot.get("state_version", -1))
	if not force and current_version > incoming_version:
		return false
	snapshot = normalized
	_index_buttons()
	last_transport_error = ""
	local_connected = true
	return true

func apply_transport_error(message: String) -> void:
	last_transport_error = message
	local_connected = false

func enter_recovery(reason: String) -> void:
	last_transport_error = reason
	local_connected = false
	var recovery := _as_dictionary(snapshot.get("recovery", {}))
	recovery["connected"] = false
	recovery["commands_allowed"] = false
	recovery["requires_full_snapshot"] = true
	recovery["reason"] = reason
	recovery["last_applied_state_version"] = state_version()
	recovery["last_applied_sequence_number"] = sequence_number()
	snapshot["recovery"] = recovery

func apply_event(event: Dictionary) -> bool:
	if event.is_empty():
		return false
	var payload := _as_dictionary(event.get("payload", {}))
	if payload.has("snapshot") and typeof(payload["snapshot"]) == TYPE_DICTIONARY:
		return apply_snapshot(payload["snapshot"])

	var incoming_sequence := _to_int(event.get("sequence_number", 0))
	var current_sequence := sequence_number()
	if incoming_sequence > 0 and current_sequence > 0:
		if incoming_sequence <= current_sequence:
			return false
		if incoming_sequence > current_sequence + 1:
			enter_recovery("event_sequence_gap")
			return false

	var event_type := str(event.get("event_type", event.get("type", "")))
	var applied := false
	match event_type:
		"round_updated", "cabinet_snapshot", "state_changed":
			applied = apply_round_update(payload)
		"double_up_updated":
			applied = apply_double_up(payload)
		"credits_updated":
			applied = apply_credits(payload)
		"jackpot_updated":
			applied = apply_jackpot(payload)
		"recovery_required", "replay_gap":
			enter_recovery(str(payload.get("reason", event_type)))
			applied = true

	if not applied and not payload.is_empty():
		for key in ["credits", "hand", "evaluation", "double_up", "jackpot", "buttons", "presentation", "recovery", "game_state"]:
			if payload.has(key):
				snapshot[key] = payload[key]
				applied = true

	if applied:
		if event.has("state_version"):
			snapshot["state_version"] = max(state_version(), _to_int(event.get("state_version", 0)))
		if incoming_sequence > 0:
			snapshot["sequence_number"] = incoming_sequence
		_index_buttons()
		last_transport_error = ""
		local_connected = true
	return applied

func apply_round_update(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if payload.has("game_state"):
		snapshot["game_state"] = payload["game_state"]
	if payload.has("hand"):
		snapshot["hand"] = payload["hand"]
	if payload.has("evaluation"):
		snapshot["evaluation"] = payload["evaluation"]
	if payload.has("buttons"):
		snapshot["buttons"] = payload["buttons"]
	if payload.has("presentation"):
		snapshot["presentation"] = payload["presentation"]
	return true

func apply_double_up(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if payload.has("double_up"):
		snapshot["double_up"] = payload["double_up"]
	else:
		snapshot["double_up"] = payload
	return true

func apply_credits(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if payload.has("credits"):
		snapshot["credits"] = payload["credits"]
	else:
		snapshot["credits"] = payload
	return true

func apply_jackpot(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if payload.has("jackpot"):
		snapshot["jackpot"] = payload["jackpot"]
	else:
		snapshot["jackpot"] = payload
	return true

func _index_buttons() -> void:
	button_state.clear()
	for button in snapshot.get("buttons", []):
		if typeof(button) == TYPE_DICTIONARY:
			button_state[str(button.get("id", ""))] = button

func _normalize_snapshot(raw: Dictionary) -> Dictionary:
	var normalized := raw.duplicate(true)
	if str(normalized.get("schema_version", "")) == "v1":
		return _normalize_legacy_snapshot(normalized)
	_normalize_button_ids(normalized)
	return normalized

func _normalize_legacy_snapshot(legacy: Dictionary) -> Dictionary:
	var ui_hints := _as_dictionary(legacy.get("ui_hints", {}))
	var legacy_credits := _as_dictionary(legacy.get("credits", {}))
	var legacy_hand := _as_dictionary(legacy.get("hand", {}))
	var legacy_eval := _as_dictionary(legacy.get("evaluation", {}))
	var legacy_du := _as_dictionary(legacy.get("double_up", {}))
	var legacy_jackpot := _as_dictionary(legacy.get("jackpot", {}))
	var jackpot_values := _as_dictionary(legacy_jackpot.get("current_values", {}))
	var machine_id_value := _to_int(legacy.get("machine_id", 1))
	var held_indexes := []
	for held in _as_array(legacy_hand.get("held_indexes", legacy_hand.get("held", []))):
		held_indexes.append(_to_int(held))

	var normalized := {
		"schema_version": "cabinet.v1",
		"message_type": "cabinet_snapshot",
		"state_version": _to_int(legacy.get("state_version", 0)),
		"sequence_number": _to_int(legacy.get("sequence_number", legacy.get("state_version", 0))),
		"server_time_utc": str(legacy.get("timestamp", "")),
		"session": {
			"session_id": str(legacy.get("session_id", "")),
			"authenticated_user_id": str(legacy.get("authenticated_user_id", "legacy")),
			"machine_id": machine_id_value,
			"is_machine_closed": false,
			"can_cash_out": bool(_to_int(legacy_credits.get("total_won", 0)) > 0),
			"visibility": "foreground",
			"started_at_utc": str(legacy.get("timestamp", "")),
			"last_seen_utc": str(legacy.get("timestamp", ""))
		},
		"machine": {
			"machine_id": machine_id_value,
			"name": "Lucky5 Classic",
			"is_open": true,
			"min_bet": str(legacy_credits.get("denomination", legacy_credits.get("bet", 0))),
			"max_bet": str(max(_to_int(legacy_credits.get("bet", 0)), _to_int(legacy_credits.get("denomination", 0))) * 200),
			"machine_serial": str(legacy_jackpot.get("machine_serial", "0")),
			"machine_serie": str(legacy_jackpot.get("machine_serie", "0")),
			"machine_kent": str(legacy_jackpot.get("machine_kent", "0")),
			"first_recharge_credit": "0",
			"second_recharge_credit": "0",
			"first_recharge_bonus": "0",
			"second_recharge_bonus": "0"
		},
		"variant": {
			"variant_id": str(legacy.get("variant_id", "lucky5.classic")),
			"variant_schema_version": "variant.v1",
			"paytable_hash": "legacy",
			"display_name": "Lucky5 Classic",
			"cabinet_skin_id": "lebanese_retro_v1",
			"presentation_profile_id": "retro_cabinet_v1"
		},
		"game_state": str(legacy.get("game_state", "idle")),
		"credits": {
			"machine_credits": str(legacy_credits.get("machine_credits", legacy_credits.get("balance", 0))),
			"wallet_balance": str(legacy_credits.get("wallet_balance", 0)),
			"credit_balance": str(legacy_credits.get("credit_balance", 0)),
			"stake": str(legacy_credits.get("stake", legacy_credits.get("bet", 0))),
			"total_cash_in": str(legacy_credits.get("total_cash_in", 0)),
			"cash_out_threshold": str(legacy_credits.get("cash_out_threshold", 0)),
			"pending_win_amount": str(legacy_credits.get("pending_win_amount", legacy_credits.get("total_won", 0)))
		},
		"hand": {
			"cards": _as_array(legacy_hand.get("cards", [])),
			"result_cards": _as_array(legacy_hand.get("result_cards", legacy_hand.get("cards", []))),
			"held_indexes": held_indexes,
			"round_id": legacy_hand.get("round_id", null),
			"advised_holds": legacy_hand.get("advised_holds", null)
		},
		"evaluation": {
			"hand_rank": str(legacy_eval.get("hand_rank", "None")),
			"win_amount": str(legacy_eval.get("win_amount", 0)),
			"jackpot_won": str(legacy_eval.get("jackpot_won", 0)),
			"double_up_available": bool(_to_int(legacy_eval.get("win_amount", 0)) > 0),
			"message": str(ui_hints.get("message", legacy_eval.get("message", "")))
		},
		"double_up": {
			"active": bool(legacy_du.get("active", false)),
			"current_amount": str(legacy_du.get("current_amount", legacy_credits.get("total_won", 0))),
			"switches_remaining": _to_int(legacy_du.get("switches_remaining", 0)),
			"is_no_lose_active": bool(legacy_du.get("is_no_lose_active", false)),
			"is_lucky5_active": bool(legacy_du.get("is_lucky5_active", false)),
			"status": str(legacy_du.get("status", legacy_du.get("outcome", "none"))),
			"round_id": legacy_du.get("round_id", null),
			"dealer_card": legacy_du.get("dealer_card", null),
			"challenger_card": legacy_du.get("challenger_card", null),
			"card_trail": legacy_du.get("card_trail", []),
			"lucky_multiplier": _to_int(legacy_du.get("lucky_multiplier", 1))
		},
		"jackpot": {
			"full_house": str(jackpot_values.get("full_house", legacy_jackpot.get("full_house", 0))),
			"full_house_rank": _to_int(legacy_jackpot.get("full_house_rank", 0)),
			"four_of_a_kind_a": str(jackpot_values.get("four_of_a_kind_a", legacy_jackpot.get("four_of_a_kind_a", 0))),
			"four_of_a_kind_b": str(jackpot_values.get("four_of_a_kind_b", legacy_jackpot.get("four_of_a_kind_b", 0))),
			"active_four_of_a_kind_slot": "A" if _to_int(legacy_jackpot.get("active_four_of_a_kind_slot", 0)) == 0 else "B",
			"straight_flush": str(jackpot_values.get("straight_flush", legacy_jackpot.get("straight_flush", 0)))
		},
		"buttons": _buttons_from_legacy(ui_hints),
		"presentation": {
			"layout_profile": "portrait_720x1280",
			"skin_id": "lebanese_retro_v1",
			"message": str(ui_hints.get("message", legacy_eval.get("message", ""))),
			"message_tone": "normal",
			"pacing_profile": "classic_arcade",
			"effects": []
		},
		"recovery": {
			"connected": true,
			"commands_allowed": true,
			"requires_full_snapshot": false,
			"last_applied_state_version": _to_int(legacy.get("state_version", 0)),
			"last_applied_sequence_number": _to_int(legacy.get("sequence_number", legacy.get("state_version", 0))),
			"reason": ""
		}
	}
	return normalized

func _buttons_from_legacy(ui_hints: Dictionary) -> Array:
	var enabled_lookup := {}
	for id in _as_array(ui_hints.get("enabled_buttons", [])):
		enabled_lookup[_normalize_button_id(str(id))] = true
	var ids := ["menu", "bet", "deal_draw", "cancel_hold", "hold_0", "hold_1", "hold_2", "hold_3", "hold_4", "big", "small", "swap_double_up_card", "take_half", "take_score", "cash_in", "cash_out", "back_to_lobby", "logout"]
	var buttons := []
	for id in ids:
		buttons.append({
			"id": id,
			"enabled": bool(enabled_lookup.get(id, false)),
			"visible": true,
			"pressed": false,
			"reason": "" if bool(enabled_lookup.get(id, false)) else "disabled_by_legacy_snapshot"
		})
	return buttons

func _normalize_button_ids(target: Dictionary) -> void:
	var buttons := []
	var seen := {}
	for button in _as_array(target.get("buttons", [])):
		if typeof(button) != TYPE_DICTIONARY:
			continue
		var normalized_button: Dictionary = button.duplicate(true)
		normalized_button["id"] = _normalize_button_id(str(normalized_button.get("id", "")))
		var id := str(normalized_button["id"])
		if id.is_empty() or seen.has(id):
			continue
		seen[id] = true
		buttons.append(normalized_button)
	target["buttons"] = buttons

func _normalize_button_id(id: String) -> String:
	return str(BUTTON_ID_ALIASES.get(id, id))

func _as_dictionary(value) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _as_array(value) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

func can_press(button_id: String) -> bool:
	var button: Dictionary = button_state.get(button_id, {})
	return bool(button.get("visible", true)) and bool(button.get("enabled", false)) and commands_allowed()

func button_reason(button_id: String) -> String:
	var button: Dictionary = button_state.get(button_id, {})
	return str(button.get("reason", ""))

func commands_allowed() -> bool:
	var recovery: Dictionary = snapshot.get("recovery", {})
	return bool(recovery.get("commands_allowed", true)) and not bool(recovery.get("requires_full_snapshot", false))

func state_version() -> int:
	return int(snapshot.get("state_version", 0))

func sequence_number() -> int:
	return int(snapshot.get("sequence_number", 0))

func machine_id(default_id: int) -> int:
	return int(snapshot.get("machine", {}).get("machine_id", default_id))

func session_id() -> String:
	return str(snapshot.get("session", {}).get("session_id", ""))

func game_state() -> String:
	return str(snapshot.get("game_state", "idle"))

func machine_name() -> String:
	return str(snapshot.get("machine", {}).get("name", "Lucky5"))

func min_bet() -> int:
	return _to_int(snapshot.get("machine", {}).get("min_bet", 0))

func max_bet() -> int:
	return _to_int(snapshot.get("machine", {}).get("max_bet", min_bet()))

func stake() -> int:
	return _to_int(snapshot.get("credits", {}).get("stake", min_bet()))

func machine_credits() -> int:
	return _to_int(snapshot.get("credits", {}).get("machine_credits", 0))

func wallet_balance() -> int:
	return _to_int(snapshot.get("credits", {}).get("wallet_balance", 0))

func credit_balance() -> int:
	return _to_int(snapshot.get("credits", {}).get("credit_balance", 0))

func total_cash_in() -> int:
	return _to_int(snapshot.get("credits", {}).get("total_cash_in", 0))

func pending_win_amount() -> int:
	return _to_int(snapshot.get("credits", {}).get("pending_win_amount", 0))

func current_round_id() -> String:
	var hand: Dictionary = snapshot.get("hand", {})
	var round_id = hand.get("round_id", null)
	if round_id == null:
		round_id = snapshot.get("double_up", {}).get("round_id", null)
	return "" if round_id == null else str(round_id)

func held_indexes() -> Array:
	var held := []
	for value in snapshot.get("hand", {}).get("held_indexes", []):
		held.append(int(value))
	return held

func cards() -> Array:
	return snapshot.get("hand", {}).get("cards", [])

func result_cards() -> Array:
	return snapshot.get("hand", {}).get("result_cards", cards())

func hand_rank() -> String:
	return str(snapshot.get("evaluation", {}).get("hand_rank", "None"))

func message() -> String:
	var presentation: Dictionary = snapshot.get("presentation", {})
	if presentation.has("message"):
		return str(presentation.get("message"))
	return str(snapshot.get("evaluation", {}).get("message", ""))

func recovery_message() -> String:
	var recovery: Dictionary = snapshot.get("recovery", {})
	if not last_transport_error.is_empty():
		return last_transport_error
	return str(recovery.get("reason", ""))

func jackpot_line() -> String:
	var jp: Dictionary = snapshot.get("jackpot", {})
	return "FULL HOUSE %s (%s)\n4 KIND A %s  4 KIND B %s  STAR %s\nSTRAIGHT FLUSH %s" % [
		_format_amount(jp.get("full_house", 0)),
		str(jp.get("full_house_rank", "")),
		_format_amount(jp.get("four_of_a_kind_a", 0)),
		_format_amount(jp.get("four_of_a_kind_b", 0)),
		str(jp.get("active_four_of_a_kind_slot", "A")),
		_format_amount(jp.get("straight_flush", 0))
	]

func credit_line() -> String:
	return "CREDIT %s\nWALLET %s\nBONUS %s\nSTAKE %s\nIN %s" % [
		_format_amount(machine_credits()),
		_format_amount(wallet_balance()),
		_format_amount(credit_balance()),
		_format_amount(stake()),
		_format_amount(total_cash_in())
	]

func _to_int(value) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING:
		var text := str(value).strip_edges()
		return int(float(text)) if text.is_valid_float() else 0
	return 0

func _format_amount(value) -> String:
	var amount: int = _to_int(value)
	var sign: String = "" if amount >= 0 else "-"
	var text: String = str(abs(amount))
	var chunks: Array[String] = []
	while text.length() > 3:
		chunks.push_front(text.substr(text.length() - 3, 3))
		text = text.substr(0, text.length() - 3)
	chunks.push_front(text)
	var formatted := ""
	for index in range(chunks.size()):
		if index > 0:
			formatted += ","
		formatted += chunks[index]
	return sign + formatted
