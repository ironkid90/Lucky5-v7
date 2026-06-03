extends RefCounted
class_name CabinetStore

var snapshot: Dictionary = {}
var button_state: Dictionary = {}
var last_transport_error: String = ""
var local_connected: bool = false

func apply_snapshot(next_snapshot: Dictionary, force: bool = false) -> bool:
    if next_snapshot.is_empty():
        return false
    var incoming_version: int = int(next_snapshot.get("state_version", 0))
    var current_version: int = int(snapshot.get("state_version", -1))
    if not force and current_version > incoming_version:
        return false
    snapshot = next_snapshot.duplicate(true)
    _index_buttons()
    last_transport_error = ""
    local_connected = true
    return true

func apply_transport_error(message: String) -> void:
    last_transport_error = message
    local_connected = false

func _index_buttons() -> void:
    button_state.clear()
    for button in snapshot.get("buttons", []):
        if typeof(button) == TYPE_DICTIONARY:
            button_state[str(button.get("id", ""))] = button

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
        return int(float(value)) if not str(value).is_empty() else 0
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
