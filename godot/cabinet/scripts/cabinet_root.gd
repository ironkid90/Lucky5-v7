extends Control
class_name CabinetRoot

const CabinetApiScript = preload("res://scripts/cabinet_api.gd")
const CabinetStoreScript = preload("res://scripts/cabinet_store.gd")

# ─── theme constants (web arcade cabinet palette) ───
const COLOR_BG := Color(0.020, 0.012, 0.008, 1.0)           # #050302
const COLOR_SCREEN := Color(0.04, 0.025, 0.018, 1.0)        # #0A0605
const COLOR_GOLD := Color(1.0, 0.843, 0.0, 1.0)              # #FFD700
const COLOR_GOLD_DIM := Color(0.651, 0.486, 0.078, 1.0)      # #a67c1a
const COLOR_GOLD_DARK := Color(0.545, 0.412, 0.078, 1.0)     # #8B6914
const COLOR_CREAM := Color(0.91, 0.831, 0.294, 1.0)          # #e8d48b
const COLOR_GREEN := Color(0.2, 1.0, 0.2, 1.0)               # #33ff33
const COLOR_GREEN_DIM := Color(0.0, 0.733, 0.0, 1.0)          # #00bb00
const COLOR_RED := Color(1.0, 0.2, 0.2, 1.0)
const COLOR_BLUE := Color(0.267, 0.867, 1.0, 1.0)            # #44ddff
const COLOR_WHITE := Color(0.95, 0.95, 0.95, 1.0)
const COLOR_GREY := Color(0.4, 0.4, 0.4, 1.0)
const COLOR_PANEL_BG := Color(0.196, 0.125, 0.051, 0.97)    # #32200d
const COLOR_PANEL_BORDER := Color(0.651, 0.486, 0.078, 1.0)

const CARD_SIZE := Vector2(110, 154)
const CARD_SMALL_SIZE := Vector2(80, 112)
const CARD_GAP := 6
const DEAL_DURATION := 0.35
const DEAL_STAGGER := 0.12
const DU_SWITCH_DURATION := 0.22
const COMMAND_TIMEOUT_SECONDS := 15.0

# ─── state vars ───
var api: CabinetApi
var store: CabinetStore = CabinetStoreScript.new()

var api_base_url := "http://127.0.0.1:8080"
var access_token := ""
var refresh_token := ""
var token_expires_at := 0.0
var auth_username := "admin"
var auth_password := "admin123"
var configured_machine_id := 1
var selected_bet := 200000
var cash_in_amount := 200000
var client_sequence := 0
var local_hold_indexes: Array = []
var last_game_state := ""
var authenticating := false
var pending_signup_username := ""
var pending_signup_password := ""
var auth_status := "LOGIN REQUIRED - SIGN IN TO PLAY"
var cards_texture_rects: Array = []
var du_cards: Array = []
var active_screen := "game"
var admin_search_results: Array = []
var admin_machine_list: Array = []
var pending_command_id := ""
var pending_idempotency_key := ""
var pending_command_type := ""

# ─── node refs ───
var title_label: Label
var paytable_labels: Array = []
var credit_label: Label
var jackpot_counters: Dictionary = {}
var message_label: Label
var recovery_label: Label
var auth_panel: VBoxContainer
var auth_message_label: Label
var username_edit: LineEdit
var password_edit: LineEdit
var phone_edit: LineEdit
var otp_edit: LineEdit
var cash_in_edit: LineEdit
var bet_label: Label
var action_buttons: Dictionary = {}
var card_container: HBoxContainer
var du_dealer_rect: TextureRect
var du_challenger_rect: TextureRect
var du_trail_container: HBoxContainer
var du_info_panel: VBoxContainer
var du_label_node: Label
var du_guess_node: Label
var du_switch_node: Label
var du_lucky_node: Label
var admin_screen: VBoxContainer
var admin_users_list: VBoxContainer
var admin_machines_list: VBoxContainer
var admin_search_edit: LineEdit
var win_amount_label: Label
var win_slot_label: Label
var machine_info_bg: Panel
var machine_serie_label: Label
var machine_kent_label: Label
var machine_serial_label: Label
var lucky5_banner: Label
var crt_overlay: ColorRect
var heartbeat_timer: Timer
var replay_timer: Timer
var token_refresh_timer: Timer
var command_timeout_timer: Timer
var deal_timer: Timer
var deal_queue: Array = []
var deal_queue_index := 0
var du_anim_queue: Array = []
var _prev_dealer_code := ""
var _prev_challenger_code := ""

# ─── lifecycle ───
func _ready() -> void:
	_load_environment()
	_build_ui()
	_load_fixture_snapshot()

	api = CabinetApiScript.new()
	add_child(api)
	api.configure(api_base_url, access_token)
	api.request_completed.connect(_on_api_response)

	heartbeat_timer = Timer.new(); heartbeat_timer.wait_time = 20.0; heartbeat_timer.autostart = true
	heartbeat_timer.timeout.connect(_send_heartbeat); add_child(heartbeat_timer)

	replay_timer = Timer.new(); replay_timer.wait_time = 3.0; replay_timer.one_shot = true
	replay_timer.timeout.connect(_request_replay); add_child(replay_timer)

	token_refresh_timer = Timer.new(); token_refresh_timer.wait_time = 60.0; token_refresh_timer.autostart = true
	token_refresh_timer.timeout.connect(_check_token_refresh); add_child(token_refresh_timer)

	command_timeout_timer = Timer.new(); command_timeout_timer.wait_time = COMMAND_TIMEOUT_SECONDS; command_timeout_timer.one_shot = true
	command_timeout_timer.timeout.connect(_on_command_timeout); add_child(command_timeout_timer)

	deal_timer = Timer.new(); deal_timer.wait_time = DEAL_STAGGER; deal_timer.one_shot = true
	deal_timer.timeout.connect(_process_deal_queue); add_child(deal_timer)

	if access_token.is_empty():
		store.apply_transport_error("Log in to play against the local Lucky5 API.")
		_refresh_ui()
	else:
		auth_status = "SIGNED IN - LOADING CABINET"
		_request_snapshot()

# ─── env loader ───
func _load_environment() -> void:
	var env_base := OS.get_environment("LUCKY5_API_BASE_URL")
	if not env_base.is_empty(): api_base_url = env_base
	access_token = OS.get_environment("LUCKY5_ACCESS_TOKEN")
	auth_username = OS.get_environment("LUCKY5_AUTH_USERNAME")
	if auth_username.is_empty(): auth_username = OS.get_environment("LUCKY5_USERNAME")
	auth_password = OS.get_environment("LUCKY5_AUTH_PASSWORD")
	if auth_password.is_empty(): auth_password = OS.get_environment("LUCKY5_PASSWORD")
	var env_machine := OS.get_environment("LUCKY5_MACHINE_ID")
	if not env_machine.is_empty() and env_machine.is_valid_int(): configured_machine_id = int(env_machine)

# ─── helper: create styled label ───
func _make_label(text_str: String, size: int, color_val: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text_str
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color_val)
	l.horizontal_alignment = align
	return l

func _make_button(text_str: String, min_h: int, bg: Color, fg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text_str
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	style.content_margin_left = 8; style.content_margin_right = 8
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = bg.lightened(0.1)
	b.add_theme_stylebox_override("hover", hover)
	var disabled := style.duplicate()
	disabled.bg_color = Color(bg.r * 0.25, bg.g * 0.25, bg.b * 0.25, 0.5)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3, 0.6))
	return b

# ─── UI builder ───
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	crt_overlay = ColorRect.new()
	crt_overlay.color = Color(0, 0, 0, 0.08)
	crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crt_overlay)
	_create_scanlines()

	var root := ScrollContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	title_label = _make_label("LUCKY 5\nLucky5 Classic", 28, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(title_label)

	_build_auth_panel(content)

	_build_paytable(content)

	lucky5_banner = _make_label("", 12, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	lucky5_banner.visible = false
	content.add_child(lucky5_banner)

	_build_credit_bar(content)
	_build_card_area(content)
	_build_win_display(content)
	_build_machine_info(content)
	_build_du_info(content)

	message_label = _make_label("INSERT COIN", 18, COLOR_GREEN_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(0, 48)
	content.add_child(message_label)

	recovery_label = _make_label("", 14, COLOR_RED, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(recovery_label)

	var inputs := HBoxContainer.new()
	inputs.add_theme_constant_override("separation", 8)
	content.add_child(inputs)
	var cash_label := _make_label("CASH IN", 12, COLOR_CREAM)
	inputs.add_child(cash_label)
	cash_in_edit = LineEdit.new()
	cash_in_edit.text = str(cash_in_amount)
	cash_in_edit.custom_minimum_size = Vector2(140, 36)
	inputs.add_child(cash_in_edit)
	bet_label = _make_label("BET %s" % selected_bet, 16, COLOR_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	bet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inputs.add_child(bet_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)

	var gold_grad := Color(0.686, 0.396, 0.078, 1.0)
	var red_grad := Color(0.733, 0.133, 0.133, 1.0)
	var green_grad := Color(0.0, 0.533, 0.0, 1.0)
	var blue_grad := Color(0.133, 0.4, 0.733, 1.0)

	var btn_defs := [
		["cash_in", "CASH IN", green_grad, COLOR_WHITE, Color(0.133, 0.733, 0.133)],
		["bet", "BET", gold_grad, COLOR_BG, COLOR_GOLD_DARK],
		["deal_draw", "DEAL", red_grad, COLOR_WHITE, Color(0.867, 0.133, 0.133)],
		["cancel_hold", "CANCEL\nHOLD", Color(0.533, 0.267, 0.078, 1.0), COLOR_WHITE, COLOR_GOLD_DARK],
		["big", "BIG", green_grad, COLOR_WHITE, Color(0.133, 0.733, 0.133)],
		["small", "SMALL", red_grad, COLOR_WHITE, Color(0.867, 0.133, 0.133)],
		["swap_double_up_card", "SWAP\nCARD", gold_grad, COLOR_BG, COLOR_GOLD_DARK],
		["take_half", "TAKE\nHALF", blue_grad, COLOR_WHITE, Color(0.267, 0.533, 0.867)],
		["take_score", "TAKE\nSCORE", gold_grad, COLOR_BG, COLOR_GOLD_DARK],
		["cash_out", "CASH OUT", red_grad, COLOR_WHITE, Color(0.867, 0.133, 0.133)],
		["reconnect_sync", "RECONNECT", blue_grad, COLOR_WHITE, Color(0.267, 0.533, 0.867)],
		["back_to_lobby", "LOBBY", gold_grad, COLOR_BG, COLOR_GOLD_DARK],
		["admin_toggle", "ADMIN", Color(0.467, 0.133, 0.467, 1.0), COLOR_WHITE, Color(0.6, 0.2, 0.6)],
		["logout", "LOGOUT", COLOR_GREY, COLOR_WHITE, Color(0.533, 0.533, 0.533)],
	]
	for def in btn_defs:
		var b := _make_button(def[1], 56, def[2], def[3], def[4])
		b.pressed.connect(_on_action_pressed.bind(def[0]))
		action_buttons[def[0]] = b
		grid.add_child(b)

	_build_admin_screen(content)

func _create_scanlines() -> void:
	var sl := ColorRect.new()
	sl.color = Color(0, 0, 0, 0.06)
	sl.set_anchors_preset(Control.PRESET_FULL_RECT)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sl)

func _build_auth_panel(parent: Node) -> void:
	auth_panel = VBoxContainer.new()
	auth_panel.add_theme_constant_override("separation", 4)
	parent.add_child(auth_panel)

	auth_message_label = _make_label("LOGIN REQUIRED", 16, COLOR_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	auth_panel.add_child(auth_message_label)

	var fields := GridContainer.new()
	fields.columns = 2
	fields.add_theme_constant_override("h_separation", 6)
	fields.add_theme_constant_override("v_separation", 4)
	auth_panel.add_child(fields)

	for pair in [["USERNAME", "player or admin"], ["PASSWORD", ""], ["PHONE", "signup only"], ["OTP", "code after signup"]]:
		fields.add_child(_make_label(pair[0], 12, COLOR_CREAM))
		var e := LineEdit.new()
		e.placeholder_text = pair[1]
		e.custom_minimum_size = Vector2(0, 34)
		if pair[0] == "PASSWORD": e.secret = true
		fields.add_child(e)
		if pair[0] == "USERNAME": username_edit = e
		elif pair[0] == "PASSWORD": password_edit = e
		elif pair[0] == "PHONE": phone_edit = e
		elif pair[0] == "OTP": otp_edit = e

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	auth_panel.add_child(btns)
	for tup in [["LOGIN", _on_login_pressed], ["SIGNUP", _on_signup_pressed], ["VERIFY OTP", _on_verify_otp_pressed]]:
		var b := _make_button(tup[0], 38, COLOR_PANEL_BG.lightened(0.15), COLOR_GOLD, COLOR_GOLD_DARK)
		b.pressed.connect(tup[1])
		btns.add_child(b)

func _build_paytable(parent: Node) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.078, 0.039, 0.016, 0.8)
	ps.border_color = COLOR_GOLD_DARK
	ps.border_width_left = 1; ps.border_width_right = 1
	ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.corner_radius_top_left = 6; ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6; ps.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var pbox := VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 1)
	panel.add_child(pbox)

	var hands := [
		["ROYAL FLUSH", 1000, Color(1.0, 0.847, 0.302)],
		["STRAIGHT FLUSH", 75, COLOR_RED],
		["FOUR OF A KIND", 15, COLOR_GREEN_DIM],
		["FULL HOUSE", 12, Color(0.498, 0.843, 1.0)],
		["FLUSH", 10, COLOR_RED],
		["STRAIGHT", 8, COLOR_WHITE],
		["THREE OF A KIND", 3, COLOR_BLUE],
		["TWO PAIR", 2, COLOR_WHITE],
	]
	for hand in hands:
		var row := HBoxContainer.new()
		var name_l := _make_label(hand[0], 12, hand[2])
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(_make_label("x%s" % hand[1], 12, hand[2], HORIZONTAL_ALIGNMENT_RIGHT))
		pbox.add_child(row)

func _build_credit_bar(parent: Node) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	parent.add_child(bar)

	credit_label = _make_label("", 12, COLOR_GREEN)
	bar.add_child(credit_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var stake_label := Label.new()
	stake_label.text = "STAKE"
	stake_label.add_theme_font_size_override("font_size", 10)
	stake_label.add_theme_color_override("font_color", COLOR_GOLD)
	stake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(stake_label)

func _build_card_area(parent: Node) -> void:
	var bg_panel := Panel.new()
	var cps := StyleBoxFlat.new()
	cps.bg_color = Color(0.02, 0.01, 0.005, 0.6)
	cps.border_color = COLOR_GOLD_DARK
	cps.border_width_left = 1; cps.border_width_right = 1
	cps.border_width_top = 1; cps.border_width_bottom = 1
	cps.corner_radius_top_left = 8; cps.corner_radius_top_right = 8
	cps.corner_radius_bottom_left = 8; cps.corner_radius_bottom_right = 8
	bg_panel.add_theme_stylebox_override("panel", cps)
	bg_panel.custom_minimum_size = Vector2(0, 180)
	parent.add_child(bg_panel)

	card_container = HBoxContainer.new()
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	card_container.add_theme_constant_override("separation", CARD_GAP)
	bg_panel.add_child(card_container)

	for index in range(5):
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 2)

		var tr := TextureRect.new()
		tr.custom_minimum_size = CARD_SIZE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.modulate = Color(0, 0, 0, 0)
		tr.mouse_filter = Control.MOUSE_FILTER_STOP
		tr.gui_input.connect(_on_card_gui_input.bind(index))
		slot.add_child(tr)

		var hold_label := _make_label("", 10, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		slot.add_child(hold_label)

		cards_texture_rects.append({"rect": tr, "hold_label": hold_label, "tween": null})
		card_container.add_child(slot)

func _build_win_display(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	win_slot_label = _make_label("", 12, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	row.add_child(win_slot_label)
	win_amount_label = _make_label("", 22, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	row.add_child(win_amount_label)

func _build_machine_info(parent: Node) -> void:
	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.078, 0.039, 0.016, 0.5)
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)
	machine_info_bg = panel

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	machine_serie_label = _make_label("SERIE 0", 11, COLOR_GREEN)
	hbox.add_child(machine_serie_label)
	machine_kent_label = _make_label("KENT 0", 11, COLOR_GREEN)
	hbox.add_child(machine_kent_label)
	machine_serial_label = _make_label("S/N 0", 12, COLOR_GOLD)
	machine_serial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	machine_serial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(machine_serial_label)

	var jp_row := HBoxContainer.new()
	jp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	jp_row.add_theme_constant_override("separation", 10)
	panel.add_child(jp_row)

	for slot in [["4K-A", "4k-a", COLOR_GREEN_DIM], ["SF", "sf", COLOR_RED], ["4K-B", "4k-b", COLOR_GREEN_DIM], ["FH", "fh", Color(0.498, 0.843, 1.0)]]:
		var tag := _make_label(slot[0], 10, slot[2])
		jp_row.add_child(tag)
		var val := _make_label("0", 14, COLOR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		jp_row.add_child(val)
		jackpot_counters[slot[1]] = val

func _build_du_info(parent: Node) -> void:
	du_info_panel = VBoxContainer.new()
	du_info_panel.visible = false
	du_info_panel.add_theme_constant_override("separation", 2)
	parent.add_child(du_info_panel)

	du_label_node = _make_label("HI LO GAMBLE", 14, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	du_info_panel.add_child(du_label_node)

	var du_cards_row := HBoxContainer.new()
	du_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	du_cards_row.add_theme_constant_override("separation", 8)
	du_info_panel.add_child(du_cards_row)

	var dealer_slot := VBoxContainer.new()
	var dl := _make_label("DEALER", 9, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	dealer_slot.add_child(dl)
	du_dealer_rect = TextureRect.new()
	du_dealer_rect.custom_minimum_size = CARD_SMALL_SIZE
	du_dealer_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	du_dealer_rect.stretch_mode = TextureRect.STRETCH_SCALE
	dealer_slot.add_child(du_dealer_rect)
	du_cards_row.add_child(dealer_slot)

	var vs_label := _make_label("VS", 12, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	du_cards_row.add_child(vs_label)

	var chall_slot := VBoxContainer.new()
	var cl := _make_label("YOU", 9, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	chall_slot.add_child(cl)
	du_challenger_rect = TextureRect.new()
	du_challenger_rect.custom_minimum_size = CARD_SMALL_SIZE
	du_challenger_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	du_challenger_rect.stretch_mode = TextureRect.STRETCH_SCALE
	chall_slot.add_child(du_challenger_rect)
	du_cards_row.add_child(chall_slot)

	var du_infos := HBoxContainer.new()
	du_infos.alignment = BoxContainer.ALIGNMENT_CENTER
	du_infos.add_theme_constant_override("separation", 12)
	du_info_panel.add_child(du_infos)

	du_guess_node = _make_label("HI OR LO", 9, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	du_infos.add_child(du_guess_node)
	du_switch_node = _make_label("", 9, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	du_infos.add_child(du_switch_node)
	du_lucky_node = _make_label("5♠ NEVER LOSE", 9, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	du_infos.add_child(du_lucky_node)

	du_trail_container = HBoxContainer.new()
	du_trail_container.alignment = BoxContainer.ALIGNMENT_CENTER
	du_trail_container.add_theme_constant_override("separation", 4)
	du_info_panel.add_child(du_trail_container)

func _build_admin_screen(parent: Node) -> void:
	admin_screen = VBoxContainer.new()
	admin_screen.visible = false
	admin_screen.add_theme_constant_override("separation", 6)
	parent.add_child(admin_screen)

	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = COLOR_PANEL_BG
	ps.border_color = COLOR_PANEL_BORDER
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.corner_radius_top_left = 8; ps.corner_radius_top_right = 8
	ps.corner_radius_bottom_left = 8; ps.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", ps)
	admin_screen.add_child(panel)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	admin_screen.add_child(tabs)

	for tup in [["ADMIN PANEL", null], ["USERS", _on_admin_users], ["MACHINES", _on_admin_machines], ["CLOSE", _on_admin_close]]:
		if tup[0] == "ADMIN PANEL":
			var l := _make_label(tup[0], 18, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tabs.add_child(l)
		else:
			var b := _make_button(tup[0], 38, COLOR_PANEL_BG.lightened(0.15), COLOR_CREAM, COLOR_GOLD_DARK)
			if tup[1] != null: b.pressed.connect(tup[1])
			tabs.add_child(b)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	admin_screen.add_child(search_row)
	admin_search_edit = LineEdit.new()
	admin_search_edit.placeholder_text = "SEARCH USERNAME"
	admin_search_edit.custom_minimum_size = Vector2(0, 34)
	admin_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(admin_search_edit)
	var sb := _make_button("SEARCH", 34, COLOR_PANEL_BG.lightened(0.2), COLOR_GOLD, COLOR_GOLD_DARK)
	sb.pressed.connect(_on_admin_search)
	search_row.add_child(sb)

	admin_users_list = VBoxContainer.new()
	admin_users_list.add_theme_constant_override("separation", 2)
	admin_screen.add_child(admin_users_list)

	admin_machines_list = VBoxContainer.new()
	admin_machines_list.add_theme_constant_override("separation", 2)
	admin_machines_list.visible = false
	admin_screen.add_child(admin_machines_list)

# ─── snapshot / auth ───
func _load_fixture_snapshot() -> void:
	var file := FileAccess.open("res://data/fixture_snapshot.json", FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		store.apply_snapshot(parsed, true)
		selected_bet = max(store.min_bet(), store.stake())
		cash_in_amount = max(200000, store.min_bet())
		_refresh_ui()

func _request_snapshot() -> void: api.get_snapshot(configured_machine_id)

func _has_auth_credentials() -> bool: return not auth_username.is_empty() and not auth_password.is_empty()

func _authenticate_and_sync(reason: String) -> void:
	if authenticating: return
	if not _has_auth_credentials():
		store.apply_transport_error("Missing kiosk credentials.")
		_refresh_ui(); return
	authenticating = true
	store.apply_transport_error(reason)
	_refresh_ui()
	api.post_login(auth_username, auth_password)

func _request_replay() -> void: api.post_replay(configured_machine_id, store.state_version(), store.sequence_number())

func _send_heartbeat() -> void:
	if access_token.is_empty() or store.snapshot.is_empty(): return
	_send_command("heartbeat", {}, false, false)

# ─── API response handler ───
func _on_api_response(kind: String, ok: bool, body, _status_code: int, error_message: String) -> void:
	if kind in ["admin_users", "admin_users_search", "admin_machines"]:
		_handle_admin_response(kind, ok, body, error_message)
		return

	if not ok:
		if _status_code == 401 and _has_auth_credentials():
			_reject_action_lock("", "Session lost")
			authenticating = false
			_authenticate_and_sync("Session lost. Re-authenticating cabinet...")
			return
		if kind in ["login", "signup", "verify_otp"]:
			auth_status = _response_message(body, error_message)
			_refresh_ui(); return
		if kind == "command":
			_reject_action_lock("", error_message)
		store.apply_transport_error(error_message)
		_refresh_ui()
		if kind != "replay": replay_timer.start()
		return

	var data = _unwrap_response_data(body)
	if kind == "login" or kind == "refresh_token":
		_apply_login_response(body)
	elif kind == "signup":
		auth_status = _response_message(body, "SIGNUP OK - ENTER OTP"); _refresh_ui()
	elif kind == "verify_otp":
		auth_status = "OTP VERIFIED - LOGGING IN"; _refresh_ui()
		api.login(pending_signup_username, pending_signup_password)
	elif kind == "snapshot" and typeof(data) == TYPE_DICTIONARY:
		_apply_snapshot(data)
	elif kind == "command" and typeof(data) == TYPE_DICTIONARY:
		_handle_command_response(data)
	elif kind == "replay" and typeof(data) == TYPE_DICTIONARY:
		if data.get("requires_full_snapshot", false) and data.has("snapshot"):
			_apply_snapshot(data["snapshot"])
		elif data.has("events"): _apply_replay_events(data["events"])
		else: _request_snapshot()

func _handle_admin_response(kind: String, ok: bool, body, error_message: String) -> void:
	if not ok:
		recovery_label.text = "Admin error: " + error_message; return
	var data = _unwrap_response_data(body)
	if kind == "admin_users" or kind == "admin_users_search":
		admin_search_results = data if typeof(data) == TYPE_ARRAY else []
		_refresh_admin_users()
	elif kind == "admin_machines":
		admin_machine_list = data if typeof(data) == TYPE_ARRAY else []
		_refresh_admin_machines()

func _unwrap_response_data(body):
	if typeof(body) == TYPE_DICTIONARY and body.has("data"): return body["data"]
	return body

func _handle_command_response(data: Dictionary) -> void:
	var response_command_id := str(data.get("command_id", data.get("commandId", "")))
	var accepted := bool(data.get("accepted", false))
	var status := str(data.get("status", ""))
	var applied_state := false

	if data.has("snapshot") and typeof(data["snapshot"]) == TYPE_DICTIONARY:
		_apply_snapshot(data["snapshot"])
		applied_state = true
	elif data.has("event") and typeof(data["event"]) == TYPE_DICTIONARY:
		if store.apply_event(data["event"]):
			applied_state = true
			_refresh_ui()

	if accepted or status == "duplicate":
		_resolve_action_lock(response_command_id)
		if not applied_state:
			_request_snapshot()
		else:
			_refresh_ui()
		return

	var message := "Command rejected"
	if data.has("error") and typeof(data["error"]) == TYPE_DICTIONARY:
		message = str(data["error"].get("message", message))
	_reject_action_lock(response_command_id, message)
	store.enter_recovery(message)
	_refresh_ui()

func _response_message(body, fallback: String) -> String:
	if typeof(body) == TYPE_DICTIONARY:
		if body.has("message") and not str(body["message"]).is_empty(): return str(body["message"])
		if body.has("error") and typeof(body["error"]) == TYPE_DICTIONARY:
			var error: Dictionary = body["error"]
			if error.has("message") and not str(error["message"]).is_empty(): return str(error["message"])
	return fallback

func _apply_login_response(body) -> void:
	var data = _unwrap_response_data(body)
	if typeof(data) != TYPE_DICTIONARY: auth_status = "LOGIN FAILED"; _refresh_ui(); return
	var tokens = data.get("tokens", {})
	var token := ""
	if typeof(tokens) == TYPE_DICTIONARY:
		if tokens.has("accessToken"): token = str(tokens["accessToken"])
		elif tokens.has("AccessToken"): token = str(tokens["AccessToken"])
	if token.is_empty(): auth_status = "LOGIN FAILED - MISSING TOKEN"; _refresh_ui(); return
	access_token = token
	refresh_token = str(tokens.get("refreshToken", tokens.get("RefreshToken", "")))
	if typeof(tokens) == TYPE_DICTIONARY and tokens.has("expiresAtUtc"):
		token_expires_at = Time.get_unix_time_from_datetime_string(str(tokens["expiresAtUtc"])) if str(tokens["expiresAtUtc"]).length() > 0 else 0.0
	else: token_expires_at = Time.get_unix_time_from_system() + 28800.0
	pending_signup_username = ""; pending_signup_password = ""
	auth_status = "SIGNED IN - LOADING CABINET"
	api.set_access_token(access_token)
	_request_snapshot(); _refresh_ui()

func _check_token_refresh() -> void:
	if refresh_token.is_empty() or access_token.is_empty(): return
	var now := Time.get_unix_time_from_system()
	if token_expires_at > 0.0 and now > token_expires_at - 3600.0: _do_token_refresh()

func _do_token_refresh() -> void:
	if refresh_token.is_empty(): return
	api.post_refresh_token(refresh_token)

func _apply_replay_events(events: Array) -> void:
	var applied := false
	for event in events:
		if typeof(event) != TYPE_DICTIONARY: continue
		var payload: Variant = event.get("payload", {})
		if typeof(payload) == TYPE_DICTIONARY and payload.has("snapshot"):
			if store.apply_snapshot(payload["snapshot"]): applied = true
	if not applied: _request_snapshot()
	else: _refresh_ui()

func _apply_snapshot(next_snapshot: Dictionary) -> void:
	var previous_state := store.game_state()
	if store.apply_snapshot(next_snapshot):
		if previous_state != store.game_state() or store.game_state() != "hold":
			local_hold_indexes.clear()
		configured_machine_id = store.machine_id(configured_machine_id)
		selected_bet = clampi(selected_bet, max(1, store.min_bet()), max(store.min_bet(), store.max_bet()))
		if selected_bet == 0: selected_bet = max(1, store.stake())
		_refresh_ui()

# ─── UI refresh ───
func _refresh_ui() -> void:
	_refresh_auth_panel()
	title_label.text = "%s\n%s" % [store.machine_name(), str(store.snapshot.get("variant", {}).get("display_name", "Lucky5 Classic"))]
	credit_label.text = store.credit_line()
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

	var du_data: Dictionary = store.snapshot.get("double_up", {})
	var du_active := bool(du_data.get("active", false))

	_refresh_cards(game_state, du_active)
	_refresh_du_panel(du_data, du_active)
	_refresh_jackpots()
	_refresh_machine_info()
	_refresh_win_display()
	_refresh_lucky5_banner()
	admin_screen.visible = active_screen == "admin"

	for id in action_buttons.keys():
		var button: Button = action_buttons[id]
		button.disabled = not _is_action_enabled(id)
		if id == "deal_draw":
			button.text = "DRAW" if store.game_state() == "hold" else "DEAL"

func _refresh_cards(game_state: String, du_active: bool) -> void:
	var cards := store.cards()
	if game_state == "drawn" or game_state == "win": cards = store.result_cards()
	var previous_codes := _get_displayed_card_codes()

	for index in range(5):
		var slot: Dictionary = cards_texture_rects[index]
		if index < cards.size() and typeof(cards[index]) == TYPE_DICTIONARY:
			var card: Dictionary = cards[index]
			var code: String = card.get("code", "")
			var held := local_hold_indexes.has(index) or bool(card.get("held", false))
			slot["hold_label"].text = "HELD" if held else ""

			if code.length() >= 2:
				var rank := code.substr(0, code.length() - 1)
				var suit := code.substr(code.length() - 1, 1)
				var tex := CardSkin_Lucky5.card_texture(rank, suit)
				slot["rect"].texture = tex

				if previous_codes[index] != code:
					_animate_card_deal(index)
			else:
				slot["rect"].texture = null
				slot["rect"].modulate = Color(0, 0, 0, 0)
		else:
			slot["rect"].texture = null
			slot["rect"].modulate = Color(0, 0, 0, 0)
			slot["hold_label"].text = ""

func _get_displayed_card_codes() -> Array:
	var result: Array = []
	for slot in cards_texture_rects:
		if slot["rect"].texture != null and slot["rect"].modulate.a > 0.1:
			var path: String = str(slot["rect"].texture.resource_path)
			var fname: String = path.get_file().trim_suffix(".png")
			result.append(fname)
		else:
			result.append("")
	return result

func _animate_card_deal(index: int) -> void:
	var slot: Dictionary = cards_texture_rects[index]
	var rect: TextureRect = slot["rect"]

	if slot["tween"] != null and slot["tween"].is_valid():
		slot["tween"].kill()
	slot["tween"] = null

	var delay := index * 0.12
	rect.modulate = Color(1, 1, 1, 0)
	rect.scale = Vector2(1.0, 1.0)

	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_interval(delay)
	tw.tween_property(rect, "modulate", Color(1, 1, 1, 1), DEAL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slot["tween"] = tw

func _refresh_du_panel(du_data: Dictionary, du_active: bool) -> void:
	du_info_panel.visible = du_active
	if not du_active:
		_prev_dealer_code = ""
		_prev_challenger_code = ""
		return

	var status := str(du_data.get("status", ""))
	var switches := int(du_data.get("switches_remaining", 0))
	du_switch_node.text = "SWAPS: %d" % switches if switches > 0 else ""

	var dealer_card: Variant = du_data.get("dealer_card", {})
	var challenger_card: Variant = du_data.get("challenger_card", {})

	var dealer_code := ""
	var challenger_code := ""

	if typeof(dealer_card) == TYPE_DICTIONARY:
		dealer_code = str(dealer_card.get("code", ""))

	if typeof(challenger_card) == TYPE_DICTIONARY:
		challenger_code = str(challenger_card.get("code", ""))

	var dealer_changed := _prev_dealer_code != "" and _prev_dealer_code != dealer_code
	var challenger_changed := _prev_challenger_code != "" and _prev_challenger_code != challenger_code

	if dealer_changed or challenger_changed:
		_animate_du_switch(dealer_code, challenger_code)
	else:
		if dealer_code.length() >= 2:
			du_dealer_rect.texture = CardSkin_Lucky5.card_texture(dealer_code.substr(0, dealer_code.length() - 1), dealer_code.substr(dealer_code.length() - 1, 1))
			du_dealer_rect.modulate = Color(1, 1, 1, 1)
		if challenger_code.length() >= 2:
			du_challenger_rect.texture = CardSkin_Lucky5.card_texture(challenger_code.substr(0, challenger_code.length() - 1), challenger_code.substr(challenger_code.length() - 1, 1))
			du_challenger_rect.modulate = Color(1, 1, 1, 1)

	_prev_dealer_code = dealer_code
	_prev_challenger_code = challenger_code

	var is_lucky5 := bool(du_data.get("is_lucky5_active", false))
	var is_no_lose := bool(du_data.get("is_no_lose_active", false))
	du_lucky_node.text = "5♠ NEVER LOSE" if is_lucky5 else ""
	du_guess_node.text = "HI OR LO" if status == "guess" else ""

func _animate_du_switch(new_dealer_code: String, new_player_code: String) -> void:
	var tw := create_tween()
	tw.set_parallel(false)

	tw.tween_property(du_dealer_rect, "modulate:a", 0.0, DU_SWITCH_DURATION * 0.4).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(_on_dealer_switch_mid.bind(new_dealer_code, new_player_code))
	tw.tween_property(du_dealer_rect, "modulate:a", 1.0, DU_SWITCH_DURATION * 0.4).set_trans(Tween.TRANS_CUBIC)

func _on_dealer_switch_mid(new_dealer_code: String, new_player_code: String) -> void:
	if new_dealer_code.length() >= 2:
		du_dealer_rect.texture = CardSkin_Lucky5.card_texture(new_dealer_code.substr(0, new_dealer_code.length() - 1), new_dealer_code.substr(new_dealer_code.length() - 1, 1))

	if new_player_code.length() >= 2:
		du_challenger_rect.texture = CardSkin_Lucky5.card_texture(new_player_code.substr(0, new_player_code.length() - 1), new_player_code.substr(new_player_code.length() - 1, 1))
		du_challenger_rect.modulate = Color(1, 1, 1, 1)
		du_challenger_rect.scale = Vector2(0.0, 1.0)
		var tw2 := create_tween()
		tw2.tween_property(du_challenger_rect, "scale", Vector2(1.0, 1.0), DU_SWITCH_DURATION * 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _refresh_jackpots() -> void:
	var jp: Dictionary = store.snapshot.get("jackpot", {})
	if jackpot_counters.has("4k-a"):
		jackpot_counters["4k-a"].text = _format_amount(jp.get("four_of_a_kind_a", 0))
	if jackpot_counters.has("sf"):
		jackpot_counters["sf"].text = _format_amount(jp.get("straight_flush", 0))
	if jackpot_counters.has("4k-b"):
		jackpot_counters["4k-b"].text = _format_amount(jp.get("four_of_a_kind_b", 0))
	if jackpot_counters.has("fh"):
		jackpot_counters["fh"].text = _format_amount(jp.get("full_house", 0))

func _refresh_machine_info() -> void:
	var machine: Dictionary = store.snapshot.get("machine", {})
	machine_serie_label.text = "SERIE %s" % str(machine.get("machine_serie", "0"))
	machine_kent_label.text = "KENT %s" % str(machine.get("machine_kent", "0"))
	machine_serial_label.text = "S/N %s" % str(machine.get("machine_serial", "0"))

func _refresh_win_display() -> void:
	var credits: Dictionary = store.snapshot.get("credits", {})
	var pending := store._to_int(credits.get("pending_win_amount", 0))
	var eval: Dictionary = store.snapshot.get("evaluation", {})
	if pending > 0:
		win_slot_label.text = str(eval.get("hand_rank", "WIN"))
		win_amount_label.text = "+%s" % _format_amount(pending)
	else:
		win_slot_label.text = ""
		win_amount_label.text = ""

func _refresh_lucky5_banner() -> void:
	var du: Dictionary = store.snapshot.get("double_up", {})
	var is_lucky5 := bool(du.get("is_lucky5_active", false))
	lucky5_banner.visible = is_lucky5
	lucky5_banner.text = "LUCKY 5 IS ACTIVE" if is_lucky5 else ""

func _refresh_auth_panel() -> void:
	if auth_panel == null: return
	var needs_auth := access_token.is_empty()
	auth_panel.visible = needs_auth
	auth_message_label.text = auth_status
	if otp_edit != null: otp_edit.visible = needs_auth and not pending_signup_username.is_empty()

func _is_action_enabled(id: String) -> bool:
	if access_token.is_empty(): return false
	if _has_pending_command() and id not in ["menu", "reconnect_sync", "logout", "admin_toggle"]: return false
	if id in ["reconnect_sync", "back_to_lobby", "logout", "admin_toggle"]: return true
	if id == "take_score" and store.can_press("cash_out"): return true
	return store.can_press(id)

func _refresh_admin_users() -> void:
	for c in admin_users_list.get_children(): c.queue_free()
	if admin_search_results.is_empty():
		admin_users_list.add_child(_make_label("No users found", 12, COLOR_GREY, HORIZONTAL_ALIGNMENT_CENTER)); return
	for user in admin_search_results:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var ud: Dictionary = user if typeof(user) == TYPE_DICTIONARY else {}
		row.add_child(_make_label(str(ud.get("username", "?")), 12, COLOR_CREAM))
		row.add_child(_make_label(str(ud.get("walletBalance", "0")), 12, COLOR_GREEN, HORIZONTAL_ALIGNMENT_RIGHT))
		row.add_child(_make_label(str(ud.get("creditBalance", "0")), 12, COLOR_GREEN, HORIZONTAL_ALIGNMENT_RIGHT))
		admin_users_list.add_child(row)

func _refresh_admin_machines() -> void:
	for c in admin_machines_list.get_children(): c.queue_free()
	if admin_machine_list.is_empty():
		admin_machines_list.add_child(_make_label("No machines found", 12, COLOR_GREY, HORIZONTAL_ALIGNMENT_CENTER)); return
	for machine in admin_machine_list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var md: Dictionary = machine if typeof(machine) == TYPE_DICTIONARY else {}
		row.add_child(_make_label("#%s %s" % [str(md.get("machineId", "?")), str(md.get("name", "?"))], 12, COLOR_CREAM))
		row.add_child(_make_label(str(md.get("machineCredits", "0")), 12, COLOR_GREEN, HORIZONTAL_ALIGNMENT_RIGHT))
		admin_machines_list.add_child(row)

# ─── input handlers ───
func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _has_pending_command(): return
		if not store.can_press("hold_%d" % index): return
		if local_hold_indexes.has(index): local_hold_indexes.erase(index)
		else: local_hold_indexes.append(index); local_hold_indexes.sort()
		_refresh_ui()

func _on_action_pressed(id: String) -> void:
	match id:
		"cash_in":
			cash_in_amount = _sanitize_cash_amount(cash_in_edit.text); cash_in_edit.text = str(cash_in_amount)
			_send_command("cash_in", {"amount": str(cash_in_amount)})
		"cash_out": _send_command("cash_out", {})
		"deal_draw":
			if store.game_state() == "hold":
				var round_id := store.current_round_id()
				if not round_id.is_empty(): _send_command("draw", {"round_id": round_id, "hold_indexes": local_hold_indexes.duplicate()})
			else: _send_command("deal", {"bet_amount": str(selected_bet)})
		"bet": _cycle_bet()
		"cancel_hold": local_hold_indexes.clear(); _send_command("clear_holds", {}); _refresh_ui()
		"big": _send_double_up_guess("big")
		"small": _send_double_up_guess("small")
		"swap_double_up_card":
			var swap_round_id := store.current_round_id()
			if not swap_round_id.is_empty(): _send_command("swap_double_up_card", {"round_id": swap_round_id, "swap_position": 0})
		"take_half":
			var round_id := store.current_round_id()
			if not round_id.is_empty(): _send_command("take_half", {"round_id": round_id})
		"take_score":
			var round_id := store.current_round_id()
			if not round_id.is_empty(): _send_command("take_score", {"round_id": round_id})
			elif store.can_press("cash_out"): _send_command("cash_out", {})
		"reconnect_sync":
			if access_token.is_empty(): _authenticate_and_sync("Reconnecting cabinet session...")
			else: _request_replay()
		"back_to_lobby": _send_command("leave_machine", {}, false)
		"logout":
			if access_token.is_empty(): pass
			else: api.logout()
			get_tree().quit()
		"admin_toggle": active_screen = "admin" if active_screen != "admin" else "game"; _refresh_ui()
		"admin_users": _on_admin_users()
		"admin_machines": _on_admin_machines()

func _on_login_pressed() -> void:
	var username := username_edit.text.strip_edges(); var password := password_edit.text
	if username.is_empty() or password.is_empty(): auth_status = "ENTER USERNAME AND PASSWORD"; _refresh_ui(); return
	auth_status = "LOGGING IN"; _refresh_ui()
	if not api.login(username, password): auth_status = "LOGIN REQUEST IS BUSY"; _refresh_ui()

func _on_signup_pressed() -> void:
	var username := username_edit.text.strip_edges(); var password := password_edit.text; var phone := phone_edit.text.strip_edges()
	if username.is_empty() or password.is_empty() or phone.is_empty(): auth_status = "SIGNUP NEEDS USERNAME PASSWORD PHONE"; _refresh_ui(); return
	pending_signup_username = username; pending_signup_password = password; auth_status = "SIGNING UP"; _refresh_ui()
	if not api.signup(username, password, phone): auth_status = "SIGNUP REQUEST IS BUSY"; _refresh_ui()

func _on_verify_otp_pressed() -> void:
	var username := pending_signup_username
	if username.is_empty(): username = username_edit.text.strip_edges()
	var otp_code := otp_edit.text.strip_edges()
	if username.is_empty() or otp_code.is_empty(): auth_status = "ENTER USERNAME AND OTP"; _refresh_ui(); return
	if pending_signup_password.is_empty(): pending_signup_password = password_edit.text
	auth_status = "VERIFYING OTP"; _refresh_ui()
	if not api.verify_otp(username, otp_code): auth_status = "OTP REQUEST IS BUSY"; _refresh_ui()

func _on_admin_users() -> void:
	admin_users_list.visible = true; admin_machines_list.visible = false
	if not access_token.is_empty(): api.get_admin_users()

func _on_admin_machines() -> void:
	admin_users_list.visible = false; admin_machines_list.visible = true
	if not access_token.is_empty(): api.get_admin_machines()

func _on_admin_search() -> void:
	var q := admin_search_edit.text.strip_edges()
	if q.is_empty():
		if not access_token.is_empty(): api.get_admin_users()
	else:
		if not access_token.is_empty(): api.search_admin_users(q)

func _on_admin_close() -> void: active_screen = "game"; admin_screen.visible = false; _refresh_ui()

func _send_double_up_guess(guess: String) -> void:
	var round_id := store.current_round_id()
	if round_id.is_empty(): return
	_send_command("double_up_guess", {"round_id": round_id, "guess": guess})

func _cycle_bet() -> void:
	var min_value: int = max(1, store.min_bet()); var max_value: int = max(min_value, store.max_bet()); var step: int = min_value
	selected_bet += step
	if selected_bet > max_value: selected_bet = min_value
	_send_command("bet_change", {"bet_amount": str(selected_bet)}, false); _refresh_ui()

func _send_command(command_type: String, payload: Dictionary, expected_state: bool = true, lock_action: bool = true) -> void:
	if access_token.is_empty(): _authenticate_and_sync("No session token. Re-authenticating..."); return
	client_sequence += 1
	var command_id := _uuid_v4(); var state_version := store.state_version() if expected_state else 0; var session_id := store.session_id()
	var idempotency_key := "%s:%d:%s" % [command_type, client_sequence, command_id]
	if lock_action and not _start_action_lock(command_id, idempotency_key, command_type):
		return
	var started: bool = api.post_command({
		"message_type": "cabinet_command", "schema_version": "cabinet.v1",
		"command_id": command_id, "command_type": command_type,
		"session_id": null if session_id.is_empty() else session_id,
		"machine_id": configured_machine_id,
		"expected_state_version": state_version,
		"idempotency_key": idempotency_key,
		"client_sequence_number": client_sequence,
		"sent_at_utc": _utc_now_string(),
		"payload": payload
	})
	if not started and lock_action:
		_reject_action_lock(command_id, "Command request could not start")

func _has_pending_command() -> bool:
	return not pending_command_id.is_empty()

func _start_action_lock(command_id: String, idempotency_key: String, command_type: String) -> bool:
	if _has_pending_command():
		store.enter_recovery("Waiting for %s response." % pending_command_type)
		_refresh_ui()
		return false
	pending_command_id = command_id
	pending_idempotency_key = idempotency_key
	pending_command_type = command_type
	command_timeout_timer.start()
	_refresh_ui()
	return true

func _resolve_action_lock(command_id: String) -> void:
	if not _has_pending_command():
		return
	if not command_id.is_empty() and command_id != pending_command_id:
		store.enter_recovery("Command response did not match the pending command.")
		return
	_clear_action_lock()

func _reject_action_lock(command_id: String, reason: String) -> void:
	if not _has_pending_command():
		return
	if command_id.is_empty() or command_id == pending_command_id:
		_clear_action_lock()
	else:
		store.enter_recovery("Command rejection did not match the pending command: %s" % reason)

func _clear_action_lock() -> void:
	pending_command_id = ""
	pending_idempotency_key = ""
	pending_command_type = ""
	if command_timeout_timer != null:
		command_timeout_timer.stop()

func _on_command_timeout() -> void:
	if not _has_pending_command():
		return
	var timed_out_type: String = pending_command_type
	_clear_action_lock()
	store.enter_recovery("Timed out waiting for %s response. Applying fresh snapshot." % timed_out_type)
	_refresh_ui()
	_request_snapshot()

func _sanitize_cash_amount(text: String) -> int:
	var value: int = int(float(text)) if not text.strip_edges().is_empty() else 200000
	var unit: int = max(1, store.min_bet()); value = max(unit, value)
	return int(round(float(value) / float(unit))) * unit

func _uuid_v4() -> String:
	var rng := RandomNumberGenerator.new(); rng.randomize()
	var bytes := []; for _i in range(16): bytes.append(rng.randi_range(0, 255))
	bytes[6] = (bytes[6] & 0x0f) | 0x40; bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex_parts := []; for value in bytes: hex_parts.append("%02x" % value)
	var s := ""; for part in hex_parts: s += str(part)
	return "%s-%s-%s-%s-%s" % [s.substr(0, 8), s.substr(8, 4), s.substr(12, 4), s.substr(16, 4), s.substr(20, 12)]

func _utc_now_string() -> String: return Time.get_datetime_string_from_system(true) + "Z"

func _format_amount(value: Variant) -> String: return store._format_amount(value)

func _process_deal_queue() -> void: pass
