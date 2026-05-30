extends Control

const CabinetApiScript = preload("res://scripts/cabinet_api.gd")
const CabinetStoreScript = preload("res://scripts/cabinet_store.gd")

var api: CabinetApi
var store: CabinetStore = CabinetStoreScript.new()

var api_base_url := "http://127.0.0.1:8080"
var access_token := ""
var auth_username := ""
var auth_password := ""
var configured_machine_id := 1
var selected_bet := 200000
var cash_in_amount := 200000
var client_sequence := 0
var local_hold_indexes: Array = []
var last_game_state := ""

var title_label: Label
var paytable_label: Label
var credit_label: Label
var jackpot_label: Label
var message_label: Label
var recovery_label: Label
var auth_panel: VBoxContainer
var username_edit: LineEdit
var password_edit: LineEdit
var phone_edit: LineEdit
var otp_edit: LineEdit
var auth_message_label: Label
var cash_in_edit: LineEdit
var bet_label: Label
var card_buttons: Array = []
var action_buttons: Dictionary = {}
var heartbeat_timer: Timer
var replay_timer: Timer
<<<<<<< Updated upstream
var authenticating := false
=======
var pending_signup_username := ""
var pending_signup_password := ""
var auth_status := "LOGIN REQUIRED - SIGN IN TO PLAY"
>>>>>>> Stashed changes

func _ready() -> void:
	_load_environment()
	_build_ui()
	_load_fixture_snapshot()

	api = CabinetApiScript.new()
	add_child(api)
	api.configure(api_base_url, access_token)
	api.request_completed.connect(_on_api_response)

	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = 20.0
	heartbeat_timer.autostart = true
	heartbeat_timer.timeout.connect(_send_heartbeat)
	add_child(heartbeat_timer)

	replay_timer = Timer.new()
	replay_timer.wait_time = 3.0
	replay_timer.one_shot = true
	replay_timer.timeout.connect(_request_replay)
	add_child(replay_timer)

	if access_token.is_empty():
<<<<<<< Updated upstream
		_authenticate_and_sync("Authenticating cabinet session…")
	else:
=======
		store.apply_transport_error("Log in to play against the local Lucky5 API.")
		_refresh_ui()
	else:
		auth_status = "SIGNED IN - LOADING CABINET"
>>>>>>> Stashed changes
		_request_snapshot()

func _load_environment() -> void:
	var env_base := OS.get_environment("LUCKY5_API_BASE_URL")
	if not env_base.is_empty():
		api_base_url = env_base

	access_token = OS.get_environment("LUCKY5_ACCESS_TOKEN")
	auth_username = OS.get_environment("LUCKY5_AUTH_USERNAME")
	if auth_username.is_empty():
		auth_username = OS.get_environment("LUCKY5_USERNAME")
	auth_password = OS.get_environment("LUCKY5_AUTH_PASSWORD")
	if auth_password.is_empty():
		auth_password = OS.get_environment("LUCKY5_PASSWORD")

	var env_machine := OS.get_environment("LUCKY5_MACHINE_ID")
	if not env_machine.is_empty() and env_machine.is_valid_int():
		configured_machine_id = int(env_machine)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.04, 0.025, 0.018, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 18
	root.offset_top = 18
	root.offset_right = -18
	root.offset_bottom = -18
	add_child(root)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "LUCKY 5"
	title_label.add_theme_font_size_override("font_size", 38)
	root.add_child(title_label)

	_build_auth_panel(root)

	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(top)

	paytable_label = Label.new()
	paytable_label.text = _paytable_text()
	paytable_label.add_theme_font_size_override("font_size", 18)
	paytable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(paytable_label)

	credit_label = Label.new()
	credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit_label.add_theme_font_size_override("font_size", 20)
	credit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(credit_label)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 8)
	card_row.custom_minimum_size = Vector2(0, 190)
	root.add_child(card_row)

	for index in range(5):
		var button := Button.new()
		button.custom_minimum_size = Vector2(126, 176)
		button.text = "--"
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_card_pressed.bind(index))
		card_buttons.append(button)
		card_row.add_child(button)

	jackpot_label = Label.new()
	jackpot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jackpot_label.add_theme_font_size_override("font_size", 19)
	root.add_child(jackpot_label)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.custom_minimum_size = Vector2(0, 70)
	root.add_child(message_label)

	recovery_label = Label.new()
	recovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recovery_label.add_theme_font_size_override("font_size", 15)
	root.add_child(recovery_label)

	var inputs := HBoxContainer.new()
	inputs.add_theme_constant_override("separation", 8)
	root.add_child(inputs)

	var cash_label := Label.new()
	cash_label.text = "CASH IN"
	inputs.add_child(cash_label)

	cash_in_edit = LineEdit.new()
	cash_in_edit.text = str(cash_in_amount)
	cash_in_edit.custom_minimum_size = Vector2(160, 42)
	inputs.add_child(cash_in_edit)

	bet_label = Label.new()
	bet_label.text = "BET %s" % selected_bet
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inputs.add_child(bet_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	_add_action_button(grid, "cash_in", "CASH IN")
	_add_action_button(grid, "bet", "BET")
	_add_action_button(grid, "deal_draw", "DEAL\nDRAW")
	_add_action_button(grid, "cancel_hold", "CANCEL\nHOLD")
	_add_action_button(grid, "big", "BIG")
	_add_action_button(grid, "small", "SMALL")
	_add_action_button(grid, "take_half", "TAKE\nHALF")
	_add_action_button(grid, "take_score", "TAKE\nSCORE")
	_add_action_button(grid, "cash_out", "CASH OUT")
	_add_action_button(grid, "reconnect_sync", "RECONNECT")
	_add_action_button(grid, "back_to_lobby", "LOBBY")
	_add_action_button(grid, "logout", "LOGOUT")

func _build_auth_panel(parent: Node) -> void:
	auth_panel = VBoxContainer.new()
	auth_panel.add_theme_constant_override("separation", 6)
	parent.add_child(auth_panel)

	auth_message_label = Label.new()
	auth_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auth_message_label.add_theme_font_size_override("font_size", 18)
	auth_panel.add_child(auth_message_label)

	var fields := GridContainer.new()
	fields.columns = 2
	fields.add_theme_constant_override("h_separation", 8)
	fields.add_theme_constant_override("v_separation", 6)
	auth_panel.add_child(fields)

	var username_label := Label.new()
	username_label.text = "USERNAME"
	fields.add_child(username_label)
	username_edit = LineEdit.new()
	username_edit.placeholder_text = "player or admin"
	username_edit.custom_minimum_size = Vector2(0, 38)
	fields.add_child(username_edit)

	var password_label := Label.new()
	password_label.text = "PASSWORD"
	fields.add_child(password_label)
	password_edit = LineEdit.new()
	password_edit.secret = true
	password_edit.custom_minimum_size = Vector2(0, 38)
	fields.add_child(password_edit)

	var phone_label := Label.new()
	phone_label.text = "PHONE"
	fields.add_child(phone_label)
	phone_edit = LineEdit.new()
	phone_edit.placeholder_text = "signup only"
	phone_edit.custom_minimum_size = Vector2(0, 38)
	fields.add_child(phone_edit)

	var otp_label := Label.new()
	otp_label.text = "OTP"
	fields.add_child(otp_label)
	otp_edit = LineEdit.new()
	otp_edit.placeholder_text = "code after signup"
	otp_edit.custom_minimum_size = Vector2(0, 38)
	fields.add_child(otp_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	auth_panel.add_child(buttons)

	var login_button := Button.new()
	login_button.text = "LOGIN"
	login_button.focus_mode = Control.FOCUS_NONE
	login_button.pressed.connect(_on_login_pressed)
	buttons.add_child(login_button)

	var signup_button := Button.new()
	signup_button.text = "SIGNUP"
	signup_button.focus_mode = Control.FOCUS_NONE
	signup_button.pressed.connect(_on_signup_pressed)
	buttons.add_child(signup_button)

	var verify_button := Button.new()
	verify_button.text = "VERIFY OTP"
	verify_button.focus_mode = Control.FOCUS_NONE
	verify_button.pressed.connect(_on_verify_otp_pressed)
	buttons.add_child(verify_button)

func _add_action_button(parent: Node, id: String, label: String) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 62)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_action_pressed.bind(id))
	action_buttons[id] = button
	parent.add_child(button)

func _load_fixture_snapshot() -> void:
	var file := FileAccess.open("res://data/fixture_snapshot.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		store.apply_snapshot(parsed, true)
		selected_bet = max(store.min_bet(), store.stake())
		cash_in_amount = max(200000, store.min_bet())
		_refresh_ui()

func _request_snapshot() -> void:
	api.get_snapshot(configured_machine_id)

func _has_auth_credentials() -> bool:
	return not auth_username.is_empty() and not auth_password.is_empty()

func _authenticate_and_sync(reason: String) -> void:
	if authenticating:
		return
	if not _has_auth_credentials():
		store.apply_transport_error("Missing kiosk credentials. Configure LUCKY5_ACCESS_TOKEN or LUCKY5_AUTH_USERNAME and LUCKY5_AUTH_PASSWORD.")
		_refresh_ui()
		return
	authenticating = true
	store.apply_transport_error(reason)
	_refresh_ui()
	api.post_login(auth_username, auth_password)

func _request_replay() -> void:
	api.post_replay(configured_machine_id, store.state_version(), store.sequence_number())

func _send_heartbeat() -> void:
	if access_token.is_empty() or store.snapshot.is_empty():
		return
	_send_command("heartbeat", {}, false)

func _on_api_response(kind: String, ok: bool, body, _status_code: int, error_message: String) -> void:
	if not ok:
<<<<<<< Updated upstream
		if _status_code == 401 and _has_auth_credentials():
			authenticating = false
			_authenticate_and_sync("Session lost. Re-authenticating cabinet…")
=======
		if kind in ["login", "signup", "verify_otp"]:
			auth_status = _response_message(body, error_message)
			_refresh_ui()
>>>>>>> Stashed changes
			return
		store.apply_transport_error(error_message)
		_refresh_ui()
		if kind != "replay":
			replay_timer.start()
		return

	var data = _unwrap_response_data(body)
<<<<<<< Updated upstream
	if kind == "login" and typeof(data) == TYPE_DICTIONARY:
		authenticating = false
		var tokens = data.get("tokens", {})
		var next_token = ""
		if typeof(tokens) == TYPE_DICTIONARY:
			next_token = str(tokens.get("accessToken", ""))
		if next_token.is_empty():
			store.apply_transport_error("Cabinet login returned no access token.")
			_refresh_ui()
			return
		access_token = next_token
		api.set_access_token(access_token)
		_request_snapshot()
=======
	if kind == "login":
		_apply_login_response(body)
	elif kind == "signup":
		auth_status = _response_message(body, "SIGNUP OK - ENTER OTP")
		_refresh_ui()
	elif kind == "verify_otp":
		auth_status = "OTP VERIFIED - LOGGING IN"
		_refresh_ui()
		api.login(pending_signup_username, pending_signup_password)
>>>>>>> Stashed changes
	elif kind == "snapshot" and typeof(data) == TYPE_DICTIONARY:
		_apply_snapshot(data)
	elif kind == "command" and typeof(data) == TYPE_DICTIONARY:
		if data.has("snapshot") and typeof(data["snapshot"]) == TYPE_DICTIONARY:
			_apply_snapshot(data["snapshot"])
		elif data.has("error"):
			store.apply_transport_error(str(data["error"].get("message", "Command rejected")))
			_refresh_ui()
	elif kind == "replay" and typeof(data) == TYPE_DICTIONARY:
		if data.get("requires_full_snapshot", false) and data.has("snapshot"):
			_apply_snapshot(data["snapshot"])
		elif data.has("events"):
			_apply_replay_events(data["events"])
		else:
			_request_snapshot()

func _unwrap_response_data(body):
	if typeof(body) == TYPE_DICTIONARY and body.has("data"):
		return body["data"]
	return body

func _response_message(body, fallback: String) -> String:
	if typeof(body) == TYPE_DICTIONARY:
		if body.has("message") and not str(body["message"]).is_empty():
			return str(body["message"])
		if body.has("error") and typeof(body["error"]) == TYPE_DICTIONARY:
			var error: Dictionary = body["error"]
			if error.has("message") and not str(error["message"]).is_empty():
				return str(error["message"])
	return fallback

func _apply_login_response(body) -> void:
	var data = _unwrap_response_data(body)
	if typeof(data) != TYPE_DICTIONARY:
		auth_status = "LOGIN FAILED - BAD RESPONSE"
		_refresh_ui()
		return

	var tokens = data.get("tokens", {})
	var token := ""
	if typeof(tokens) == TYPE_DICTIONARY:
		var token_data: Dictionary = tokens
		if token_data.has("accessToken"):
			token = str(token_data["accessToken"])
		elif token_data.has("AccessToken"):
			token = str(token_data["AccessToken"])

	if token.is_empty():
		auth_status = "LOGIN FAILED - MISSING TOKEN"
		_refresh_ui()
		return

	access_token = token
	pending_signup_username = ""
	pending_signup_password = ""
	auth_status = "SIGNED IN - LOADING CABINET"
	api.set_access_token(access_token)
	_request_snapshot()
	_refresh_ui()

func _apply_replay_events(events: Array) -> void:
	var applied := false
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_data: Dictionary = event
		var payload: Variant = event_data.get("payload", {})
		if typeof(payload) == TYPE_DICTIONARY and payload.has("snapshot"):
			if store.apply_snapshot(payload["snapshot"]):
				applied = true
	if not applied:
		_request_snapshot()
	else:
		_refresh_ui()

func _apply_snapshot(next_snapshot: Dictionary) -> void:
	var previous_state := store.game_state()
	if store.apply_snapshot(next_snapshot):
		if previous_state != store.game_state() or store.game_state() != "hold":
			local_hold_indexes.clear()
		configured_machine_id = store.machine_id(configured_machine_id)
		selected_bet = clampi(selected_bet, max(1, store.min_bet()), max(store.min_bet(), store.max_bet()))
		if selected_bet == 0:
			selected_bet = max(1, store.stake())
		_refresh_ui()

func _refresh_ui() -> void:
	_refresh_auth_panel()
	title_label.text = "%s\n%s" % [store.machine_name(), str(store.snapshot.get("variant", {}).get("display_name", "Lucky5 Classic"))]
	credit_label.text = store.credit_line()
	jackpot_label.text = store.jackpot_line()
	message_label.text = store.message()
	if access_token.is_empty():
		recovery_label.text = "LOGIN: %s" % auth_status
	else:
		recovery_label.text = "" if store.commands_allowed() else "RECOVERY: %s" % store.recovery_message()
	bet_label.text = "BET %s" % _format_amount(selected_bet)

	var game_state := store.game_state()
	if last_game_state != game_state and game_state != "hold":
		local_hold_indexes.clear()
	last_game_state = game_state

	var cards := store.cards()
	if game_state == "drawn" or game_state == "win":
		cards = store.result_cards()
	for index in range(5):
		var button: Button = card_buttons[index]
		if index < cards.size() and typeof(cards[index]) == TYPE_DICTIONARY:
			var card: Dictionary = cards[index]
			var held := local_hold_indexes.has(index) or bool(card.get("held", false))
			button.text = "%s\n%s" % [str(card.get("code", "??")), "HELD" if held else ""]
		else:
			button.text = "--"
		button.disabled = not store.can_press("hold_%d" % index)

	for id in action_buttons.keys():
		var button: Button = action_buttons[id]
		button.disabled = not _is_action_enabled(id)
		if id == "deal_draw":
			button.text = "DRAW" if store.game_state() == "hold" else "DEAL"

func _refresh_auth_panel() -> void:
	if auth_panel == null:
		return
	var needs_auth := access_token.is_empty()
	auth_panel.visible = needs_auth
	auth_message_label.text = auth_status
	if otp_edit != null:
		otp_edit.visible = needs_auth and not pending_signup_username.is_empty()

func _is_action_enabled(id: String) -> bool:
	if access_token.is_empty():
		return false
	if id == "reconnect_sync":
		return true
	if id in ["back_to_lobby", "logout"]:
		return true
	if id == "take_score" and store.can_press("cash_out"):
		return true
	return store.can_press(id)

func _on_card_pressed(index: int) -> void:
	if not store.can_press("hold_%d" % index):
		return
	if local_hold_indexes.has(index):
		local_hold_indexes.erase(index)
	else:
		local_hold_indexes.append(index)
		local_hold_indexes.sort()
	_refresh_ui()

func _on_action_pressed(id: String) -> void:
	match id:
		"cash_in":
			cash_in_amount = _sanitize_cash_amount(cash_in_edit.text)
			cash_in_edit.text = str(cash_in_amount)
			_send_command("cash_in", {"amount": str(cash_in_amount)})
		"cash_out":
			_send_command("cash_out", {})
		"deal_draw":
			if store.game_state() == "hold":
				var round_id := store.current_round_id()
				if not round_id.is_empty():
					_send_command("draw", {"round_id": round_id, "hold_indexes": local_hold_indexes.duplicate()})
			else:
				_send_command("deal", {"bet_amount": str(selected_bet)})
		"bet":
			_cycle_bet()
		"cancel_hold":
			local_hold_indexes.clear()
			_send_command("clear_holds", {})
			_refresh_ui()
		"big":
			_send_double_up_guess("big")
		"small":
			_send_double_up_guess("small")
		"take_half":
			var round_id := store.current_round_id()
			if not round_id.is_empty():
				_send_command("take_half", {"round_id": round_id})
		"take_score":
			var round_id := store.current_round_id()
			if not round_id.is_empty():
				_send_command("take_score", {"round_id": round_id})
			elif store.can_press("cash_out"):
				_send_command("cash_out", {})
		"reconnect_sync":
			if access_token.is_empty():
				_authenticate_and_sync("Reconnecting cabinet session…")
			else:
				_request_replay()
		"back_to_lobby":
			_send_command("leave_machine", {}, false)
		"logout":
			if not access_token.is_empty():
				api.logout()
			get_tree().quit()

func _on_login_pressed() -> void:
	var username := username_edit.text.strip_edges()
	var password := password_edit.text
	if username.is_empty() or password.is_empty():
		auth_status = "ENTER USERNAME AND PASSWORD"
		_refresh_ui()
		return
	auth_status = "LOGGING IN"
	_refresh_ui()
	if not api.login(username, password):
		auth_status = "LOGIN REQUEST IS BUSY"
		_refresh_ui()

func _on_signup_pressed() -> void:
	var username := username_edit.text.strip_edges()
	var password := password_edit.text
	var phone := phone_edit.text.strip_edges()
	if username.is_empty() or password.is_empty() or phone.is_empty():
		auth_status = "SIGNUP NEEDS USERNAME PASSWORD PHONE"
		_refresh_ui()
		return
	pending_signup_username = username
	pending_signup_password = password
	auth_status = "SIGNING UP"
	_refresh_ui()
	if not api.signup(username, password, phone):
		auth_status = "SIGNUP REQUEST IS BUSY"
		_refresh_ui()

func _on_verify_otp_pressed() -> void:
	var username := pending_signup_username
	if username.is_empty():
		username = username_edit.text.strip_edges()
	var otp_code := otp_edit.text.strip_edges()
	if username.is_empty() or otp_code.is_empty():
		auth_status = "ENTER USERNAME AND OTP"
		_refresh_ui()
		return
	if pending_signup_password.is_empty():
		pending_signup_password = password_edit.text
	auth_status = "VERIFYING OTP"
	_refresh_ui()
	if not api.verify_otp(username, otp_code):
		auth_status = "OTP REQUEST IS BUSY"
		_refresh_ui()

func _send_double_up_guess(guess: String) -> void:
	var round_id := store.current_round_id()
	if round_id.is_empty():
		return
	_send_command("double_up_guess", {"round_id": round_id, "guess": guess})

func _cycle_bet() -> void:
	var min_value: int = max(1, store.min_bet())
	var max_value: int = max(min_value, store.max_bet())
	var step: int = min_value
	selected_bet += step
	if selected_bet > max_value:
		selected_bet = min_value
	_send_command("bet_change", {"bet_amount": str(selected_bet)}, false)
	_refresh_ui()

func _send_command(command_type: String, payload: Dictionary, expected_state: bool = true) -> void:
	if access_token.is_empty():
		_authenticate_and_sync("No session token. Re-authenticating cabinet…")
		return

	client_sequence += 1
	var command_id := _uuid_v4()
	var state_version := store.state_version() if expected_state else 0
	var session_id := store.session_id()
	var command := {
		"message_type": "cabinet_command",
		"schema_version": "cabinet.v1",
		"command_id": command_id,
		"command_type": command_type,
		"session_id": null if session_id.is_empty() else session_id,
		"machine_id": configured_machine_id,
		"expected_state_version": state_version,
		"idempotency_key": "%s:%d:%s" % [command_type, client_sequence, command_id],
		"client_sequence_number": client_sequence,
		"sent_at_utc": _utc_now_string(),
		"payload": payload
	}
	api.post_command(command)

func _sanitize_cash_amount(text: String) -> int:
	var value: int = int(float(text)) if not text.strip_edges().is_empty() else 200000
	var unit: int = max(1, store.min_bet())
	value = max(unit, value)
	value = int(round(float(value) / float(unit))) * unit
	return value

func _uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := []
	for _i in range(16):
		bytes.append(rng.randi_range(0, 255))
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex_parts := []
	for value in bytes:
		hex_parts.append("%02x" % value)
	var s := ""
	for part in hex_parts:
		s += str(part)
	return "%s-%s-%s-%s-%s" % [s.substr(0, 8), s.substr(8, 4), s.substr(12, 4), s.substr(16, 4), s.substr(20, 12)]

func _utc_now_string() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

func _paytable_text() -> String:
	return "ROYAL FLUSH     1000\nSTRAIGHT FLUSH    75\nFOUR OF A KIND    15\nFULL HOUSE        12\nFLUSH             10\nSTRAIGHT           8\nTHREE OF A KIND    3\nTWO PAIR           2"

func _format_amount(value: int) -> String:
	return store._format_amount(value)
