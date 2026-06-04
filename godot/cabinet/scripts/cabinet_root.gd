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
const COLOR_CONTROL_DECK := Color(0.290, 0.125, 0.034, 0.98)
const COLOR_CONTROL_DECK_TOP := Color(0.455, 0.224, 0.063, 0.98)
const COLOR_CONTROL_DECK_MID := Color(0.333, 0.137, 0.035, 0.98)
const COLOR_CONTROL_DECK_BOTTOM := Color(0.204, 0.071, 0.020, 0.98)
const COLOR_WOOD_GRAIN_LIGHT := Color(0.780, 0.420, 0.120, 0.34)
const COLOR_WOOD_GRAIN_DARK := Color(0.080, 0.024, 0.008, 0.46)
const COLOR_BUTTON_YELLOW := Color(1.0, 0.710, 0.070, 1.0)
const COLOR_BUTTON_ORANGE := Color(0.890, 0.345, 0.078, 1.0)
const COLOR_BUTTON_RED := Color(0.820, 0.055, 0.055, 1.0)
const COLOR_BUTTON_GREEN := Color(0.047, 0.645, 0.137, 1.0)
const COLOR_BUTTON_BLACK := Color(0.035, 0.035, 0.035, 1.0)
const BUTTON_BEVEL_SHADOW_SIZE := 5
const BUTTON_PRESSED_SHADOW_SIZE := 1
const BUTTON_ASSET_BASE_PATH := "res://skins/lucky5/buttons/"
const BUTTON_ASSET_FONT_SIZE := 13

const CARD_AREA_MIN_HEIGHT := 180
const CARD_SIZE := Vector2(122, 171)
const CARD_SMALL_SIZE := Vector2(80, 112)
const CARD_GAP := 6
const CONTROL_DECK_MIN_HEIGHT := 324
const CONTROL_HOLD_BUTTON_HEIGHT := 70
const CONTROL_ACTION_BUTTON_HEIGHT := 80
const CONTROL_BOTTOM_BUTTON_HEIGHT := 72
const DEAL_DURATION := 0.22
const DEAL_STAGGER := 0.10
const DRAW_OUT_DURATION := 0.055
const DRAW_IN_DURATION := 0.075
const DRAW_STAGGER := 0.045
const DU_SWITCH_DURATION := 0.22
const DU_BOARD_CARD_SIZE := Vector2(92, 129)
const DU_TRAIL_CARD_SIZE := Vector2(92, 129)
const DOUBLE_UP_BOARD_SLOT_COUNT := 5
const DU_SHUFFLE_INTERVAL := 0.08
const DU_SHUFFLE_TICKS := 8
const DU_SHUFFLE_CODES := ["AS", "KH", "QD", "JC", "10S", "9H", "8D", "7C"]
const DU_REVEAL_SETTLE_SECONDS := 0.50
const IDLE_FH_CARD_DELAY_SECONDS := 60.0
const IDLE_TITLE_TEXT := "LUCKY 5"
const WIN_COUNTER_MIN_DURATION := 0.18
const WIN_COUNTER_MAX_DURATION := 0.75
const JACKPOT_TRICKLE_DURATION := 0.30
const JACKPOT_DRAIN_DURATION := 2.80
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
var kiosk_auth_configured := false
var configured_machine_id := 1
var selected_bet := 200000
var cash_in_amount := 200000
var client_sequence := 0
var local_hold_indexes: Array = []
var auto_holds_cancelled := false
var auto_double_up_round_ids: Array = []
var idle_fh_rank_revealed := false
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
var admin_agent_list: Array = []
var admin_selected_agent_id := 0
var pending_command_id := ""
var pending_idempotency_key := ""
var pending_command_type := ""
var button_asset_textures: Dictionary = {}

# ─── node refs ───
var title_label: Label
var paytable_rows: Dictionary = {}
var paytable_amount_labels: Dictionary = {}
var paytable_multipliers: Dictionary = {}
var full_house_rank_label: Label
var full_house_jackpot_label: Label
var credit_label: Label
var jackpot_counters: Dictionary = {}
var jackpot_counter_panels: Dictionary = {}
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
var hold_buttons: Array = []
var menu_overlay: PanelContainer
var menu_panel: VBoxContainer
var menu_open := false
var card_area_panel: Panel
var card_container: HBoxContainer
var idle_title_label: Label
var du_dealer_rect: TextureRect
var du_challenger_rect: TextureRect
var du_dealer_label: Label
var du_challenger_label: Label
var du_trail_container: HBoxContainer
var du_info_panel: VBoxContainer
var du_label_node: Label
var du_guess_node: Label
var du_switch_node: Label
var du_lucky_node: Label
var admin_screen: VBoxContainer
var admin_user_search_row: HBoxContainer
var admin_agent_tools: VBoxContainer
var admin_users_list: VBoxContainer
var admin_machines_list: VBoxContainer
var admin_agents_list: VBoxContainer
var admin_search_edit: LineEdit
var admin_agent_name_edit: LineEdit
var admin_agent_code_edit: LineEdit
var admin_agent_phone_edit: LineEdit
var admin_agent_credit_edit: LineEdit
var win_amount_label: Label
var win_slot_label: Label
var machine_info_bg: Panel
var machine_serie_label: Label
var machine_kent_label: Label
var machine_serial_label: Label
var bonus_message_label: Label
var bonus_stage_panel: PanelContainer
var bonus_stage_card: TextureRect
var bonus_stage_label: Label
var bonus_stage_amount_label: Label
var lucky5_banner: Label
var crt_overlay: ColorRect
var heartbeat_timer: Timer
var replay_timer: Timer
var token_refresh_timer: Timer
var command_timeout_timer: Timer
var deal_timer: Timer
var du_shuffle_timer: Timer
var du_promote_timer: Timer
var idle_fh_timer: Timer
var deal_queue: Array = []
var deal_queue_index := 0
var du_anim_queue: Array = []
var du_shuffle_ticks_remaining := 0
var du_shuffle_index := 0
var du_shuffle_target_dealer := ""
var du_shuffle_target_challenger := ""
var du_pending_promote_dealer := ""
var _prev_dealer_code := ""
var _prev_challenger_code := ""
var win_displayed_amount := 0
var win_target_amount := 0
var win_counter_tween: Tween
var win_pulse_tween: Tween
var credit_pulse_tween: Tween
var bonus_stage_tween: Tween
var last_machine_credit_amount := -1
var bonus_stage_key := ""
var displayed_jackpots: Dictionary = {}
var jackpot_counter_targets: Dictionary = {}
var jackpot_counter_tweens: Dictionary = {}

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

	du_shuffle_timer = Timer.new(); du_shuffle_timer.wait_time = DU_SHUFFLE_INTERVAL; du_shuffle_timer.one_shot = false
	du_shuffle_timer.timeout.connect(_process_du_shuffle); add_child(du_shuffle_timer)

	du_promote_timer = Timer.new(); du_promote_timer.wait_time = DU_REVEAL_SETTLE_SECONDS; du_promote_timer.one_shot = true
	du_promote_timer.timeout.connect(_on_du_promote_timeout); add_child(du_promote_timer)

	idle_fh_timer = Timer.new(); idle_fh_timer.wait_time = IDLE_FH_CARD_DELAY_SECONDS; idle_fh_timer.one_shot = true
	idle_fh_timer.timeout.connect(_on_idle_fh_timer_timeout); add_child(idle_fh_timer)

	if access_token.is_empty():
		if kiosk_auth_configured and _has_auth_credentials():
			_authenticate_and_sync("Kiosk credentials found. Connecting to backend...")
			return
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
	var env_username := OS.get_environment("LUCKY5_AUTH_USERNAME")
	if env_username.is_empty(): env_username = OS.get_environment("LUCKY5_KIOSK_USERNAME")
	if env_username.is_empty(): env_username = OS.get_environment("LUCKY5_USERNAME")
	var env_password := OS.get_environment("LUCKY5_AUTH_PASSWORD")
	if env_password.is_empty(): env_password = OS.get_environment("LUCKY5_KIOSK_PASSWORD")
	if env_password.is_empty(): env_password = OS.get_environment("LUCKY5_PASSWORD")
	kiosk_auth_configured = not env_username.is_empty() and not env_password.is_empty()
	auth_username = env_username
	auth_password = env_password
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

func _make_button(text_str: String, min_h: int, bg: Color, fg: Color, border: Color, asset_key: String = "") -> Button:
	var b := Button.new()
	b.text = text_str
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 4
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	style.content_margin_left = 8; style.content_margin_right = 8
	style.content_margin_top = 6; style.content_margin_bottom = 9
	style.shadow_color = border.darkened(0.55)
	style.shadow_size = BUTTON_BEVEL_SHADOW_SIZE
	style.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = bg.lightened(0.12)
	hover.border_color = border.lightened(0.18)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = bg.darkened(0.18)
	pressed.content_margin_top = 10
	pressed.content_margin_bottom = 6
	pressed.shadow_size = BUTTON_PRESSED_SHADOW_SIZE
	pressed.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate()
	disabled.bg_color = Color(bg.r * 0.25, bg.g * 0.25, bg.b * 0.25, 0.5)
	disabled.shadow_size = 0
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3, 0.6))
	if _apply_button_asset_styles(b, asset_key):
		b.text = ""
		b.tooltip_text = text_str.replace("\n", " ")
	return b

func _apply_button_asset_styles(button: Button, asset_key: String) -> bool:
	if asset_key.is_empty():
		return false
	var normal_asset := _button_asset_normal_name(asset_key)
	var normal := _make_button_asset_style(normal_asset)
	if normal == null:
		return false
	var active := _make_button_asset_style(_button_asset_active_name(asset_key))
	if active == null:
		active = normal.duplicate()
	var disabled := _make_button_asset_style(_button_asset_disabled_name(asset_key), Color(0.35, 0.35, 0.35, 0.72))
	if disabled == null:
		disabled = normal.duplicate()
		disabled.modulate_color = Color(0.35, 0.35, 0.35, 0.72)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", active)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", COLOR_BG)
	button.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.25))
	button.add_theme_font_size_override("font_size", BUTTON_ASSET_FONT_SIZE)
	button.set_meta("uses_ai9_button_asset", true)
	return true

func _make_button_asset_style(asset_name: String, tint := Color(1, 1, 1, 1)) -> StyleBoxTexture:
	var texture := _load_button_asset_texture(asset_name)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.content_margin_left = 6; style.content_margin_right = 6
	style.content_margin_top = 8; style.content_margin_bottom = 8
	return style

func _load_button_asset_texture(asset_name: String) -> Texture2D:
	if button_asset_textures.has(asset_name):
		return button_asset_textures[asset_name] as Texture2D
	var path := BUTTON_ASSET_BASE_PATH + asset_name + ".png"
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var result := image.load(path)
	if result != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	button_asset_textures[asset_name] = texture
	return texture

func _button_asset_normal_name(asset_key: String) -> String:
	if asset_key == "hold":
		return "hold_on"
	return asset_key

func _button_asset_active_name(asset_key: String) -> String:
	if asset_key == "hold":
		return "hold_on"
	var active_name := "%s_on" % asset_key
	var active_path := BUTTON_ASSET_BASE_PATH + active_name + ".png"
	return active_name if FileAccess.file_exists(active_path) else _button_asset_normal_name(asset_key)

func _button_asset_disabled_name(asset_key: String) -> String:
	if asset_key == "hold":
		return "hold_off"
	return _button_asset_normal_name(asset_key)

func _button_uses_asset(button: Button) -> bool:
	return button != null and button.has_meta("uses_ai9_button_asset") and bool(button.get_meta("uses_ai9_button_asset"))

func _make_admin_edit(placeholder: String, min_width: int = 0) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(min_width, 34)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e

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
	root.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	var bottom_spacer := Control.new()
	bottom_spacer.name = "CabinetBottomDeckSpacer"
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bottom_spacer)

	_build_control_deck(content)
	_build_menu_panel(self)

	_build_admin_screen(content)

func _build_control_deck(parent: Node) -> void:
	var deck := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = COLOR_CONTROL_DECK
	ps.border_color = COLOR_PANEL_BORDER
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 3
	ps.corner_radius_top_left = 8; ps.corner_radius_top_right = 8
	ps.corner_radius_bottom_left = 8; ps.corner_radius_bottom_right = 8
	deck.add_theme_stylebox_override("panel", ps)
	deck.custom_minimum_size = Vector2(0, CONTROL_DECK_MIN_HEIGHT)
	parent.add_child(deck)
	_decorate_control_deck(deck)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	deck.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(rows)

	var hold_row := HBoxContainer.new()
	hold_row.name = "ArcadeHoldRow"
	hold_row.add_theme_constant_override("separation", 6)
	rows.add_child(hold_row)
	hold_buttons.clear()
	for index in range(5):
		var hold_button := _make_button("HOLD", CONTROL_HOLD_BUTTON_HEIGHT, COLOR_BUTTON_YELLOW, COLOR_BG, COLOR_GOLD_DARK, "hold")
		hold_button.name = "HoldButton%d" % (index + 1)
		hold_button.pressed.connect(_on_hold_button_pressed.bind(index))
		hold_buttons.append(hold_button)
		hold_row.add_child(hold_button)

	var action_row := HBoxContainer.new()
	action_row.name = "ArcadeActionRow"
	action_row.add_theme_constant_override("separation", 6)
	rows.add_child(action_row)
	var action_defs := [
		["big", "BIG", COLOR_BUTTON_YELLOW, COLOR_BG, COLOR_GOLD_DARK],
		["small", "SMALL", COLOR_BUTTON_YELLOW, COLOR_BG, COLOR_GOLD_DARK],
		["cancel_hold", "CANCEL\nHOLD", COLOR_WHITE, COLOR_BG, COLOR_GREY],
		["deal_draw", "DEAL\nDRAW", COLOR_BUTTON_RED, COLOR_WHITE, Color(0.950, 0.180, 0.180)],
		["bet", "BET", COLOR_BUTTON_GREEN, COLOR_WHITE, Color(0.180, 0.900, 0.260)],
	]
	for def in action_defs:
		_add_deck_action_button(action_row, def, CONTROL_ACTION_BUTTON_HEIGHT)

	var bottom_row := HBoxContainer.new()
	bottom_row.name = "ArcadeBottomRow"
	bottom_row.add_theme_constant_override("separation", 8)
	rows.add_child(bottom_row)
	var bottom_defs := [
		["take_half", "TAKE\nHALF", COLOR_BUTTON_RED, COLOR_WHITE, Color(0.950, 0.180, 0.180)],
		["menu", "MENU", COLOR_BUTTON_BLACK, COLOR_WHITE, COLOR_GREY],
		["take_score", "TAKE\nSCORE", COLOR_BUTTON_ORANGE, COLOR_BG, COLOR_GOLD_DARK],
	]
	for def in bottom_defs:
		_add_deck_action_button(bottom_row, def, CONTROL_BOTTOM_BUTTON_HEIGHT)

	bet_label = _make_label("BET %s" % selected_bet, 13, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	bet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(bet_label)

func _decorate_control_deck(deck: Control) -> void:
	_add_control_deck_band(deck, "ControlDeckBandTop", 0.0, 0.36, COLOR_CONTROL_DECK_TOP)
	_add_control_deck_band(deck, "ControlDeckBandMid", 0.32, 0.74, COLOR_CONTROL_DECK_MID)
	_add_control_deck_band(deck, "ControlDeckBandBottom", 0.70, 1.0, COLOR_CONTROL_DECK_BOTTOM)
	var grain_offsets := [12, 26, 39, 57, 73, 91, 108, 126, 145, 164, 184]
	for i in range(grain_offsets.size()):
		var color := COLOR_WOOD_GRAIN_LIGHT if i % 2 == 0 else COLOR_WOOD_GRAIN_DARK
		_add_control_deck_grain(deck, int(grain_offsets[i]), color, 1 + (i % 3))

func _add_control_deck_band(deck: Control, node_name: String, from_anchor: float, to_anchor: float, color: Color) -> void:
	var band := ColorRect.new()
	band.name = node_name
	band.color = color
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = from_anchor
	band.anchor_bottom = to_anchor
	band.offset_left = 0
	band.offset_right = 0
	band.offset_top = 0
	band.offset_bottom = 0
	deck.add_child(band)

func _add_control_deck_grain(deck: Control, y_offset: int, color: Color, height: int) -> void:
	var grain := ColorRect.new()
	grain.name = "ControlDeckGrain"
	grain.color = color
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain.anchor_left = 0.0
	grain.anchor_right = 1.0
	grain.anchor_top = 0.0
	grain.anchor_bottom = 0.0
	grain.offset_left = 8
	grain.offset_right = -8
	grain.offset_top = y_offset
	grain.offset_bottom = y_offset + height
	deck.add_child(grain)

func _add_deck_action_button(row: HBoxContainer, def: Array, min_h: int) -> void:
	var asset_key := str(def[0])
	var button := _make_button(def[1], min_h, def[2], def[3], def[4], asset_key)
	button.name = "DeckButton_%s" % str(def[0])
	button.pressed.connect(_on_action_pressed.bind(str(def[0])))
	action_buttons[str(def[0])] = button
	row.add_child(button)

func _build_menu_panel(parent: Node) -> void:
	menu_overlay = PanelContainer.new()
	menu_overlay.name = "CabinetMenuOverlay"
	menu_overlay.visible = false
	menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.74)
	menu_overlay.add_theme_stylebox_override("panel", overlay_style)
	parent.add_child(menu_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_overlay.add_child(center)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(500, 0)
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.080, 0.038, 0.014, 0.98)
	shell_style.border_color = COLOR_PANEL_BORDER
	shell_style.border_width_left = 2; shell_style.border_width_right = 2
	shell_style.border_width_top = 2; shell_style.border_width_bottom = 3
	shell_style.corner_radius_top_left = 8; shell_style.corner_radius_top_right = 8
	shell_style.corner_radius_bottom_left = 8; shell_style.corner_radius_bottom_right = 8
	shell_style.content_margin_left = 14; shell_style.content_margin_right = 14
	shell_style.content_margin_top = 12; shell_style.content_margin_bottom = 12
	shell.add_theme_stylebox_override("panel", shell_style)
	center.add_child(shell)

	menu_panel = VBoxContainer.new()
	menu_panel.name = "CabinetMenuPanel"
	menu_panel.add_theme_constant_override("separation", 6)
	shell.add_child(menu_panel)

	var title := _make_label("MENU", 16, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	menu_panel.add_child(title)

	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 8)
	menu_panel.add_child(cash_row)
	cash_row.add_child(_make_label("CASH IN", 12, COLOR_CREAM))
	cash_in_edit = LineEdit.new()
	cash_in_edit.text = str(cash_in_amount)
	cash_in_edit.custom_minimum_size = Vector2(160, 36)
	cash_in_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cash_row.add_child(cash_in_edit)

	var menu_defs := [
		["cash_in", "CASH IN", COLOR_BUTTON_GREEN, COLOR_WHITE, Color(0.180, 0.900, 0.260)],
		["cash_out", "CASH OUT", COLOR_BUTTON_RED, COLOR_WHITE, Color(0.950, 0.180, 0.180)],
		["reconnect_sync", "RECONNECT", COLOR_PANEL_BG.lightened(0.2), COLOR_GOLD, COLOR_GOLD_DARK],
		["back_to_lobby", "LOBBY", COLOR_PANEL_BG.lightened(0.15), COLOR_CREAM, COLOR_GOLD_DARK],
		["admin_toggle", "ADMIN", Color(0.467, 0.133, 0.467, 1.0), COLOR_WHITE, Color(0.6, 0.2, 0.6)],
		["logout", "LOGOUT", COLOR_GREY, COLOR_WHITE, Color(0.533, 0.533, 0.533)],
	]
	for def in menu_defs:
		var button := _make_button(def[1], 38, def[2], def[3], def[4])
		button.pressed.connect(_on_action_pressed.bind(str(def[0])))
		action_buttons[str(def[0])] = button
		menu_panel.add_child(button)

	var close_button := _make_button("CLOSE", 36, COLOR_BUTTON_BLACK, COLOR_WHITE, COLOR_GREY)
	close_button.pressed.connect(_on_menu_close_pressed)
	menu_panel.add_child(close_button)

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

	if not auth_username.is_empty(): username_edit.text = auth_username
	if not auth_password.is_empty(): password_edit.text = auth_password

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	auth_panel.add_child(btns)
	for tup in [["LOGIN", _on_login_pressed], ["SIGNUP", _on_signup_pressed], ["VERIFY OTP", _on_verify_otp_pressed]]:
		var b := _make_button(tup[0], 38, COLOR_PANEL_BG.lightened(0.15), COLOR_GOLD, COLOR_GOLD_DARK)
		b.pressed.connect(tup[1])
		btns.add_child(b)

func _build_paytable(parent: Node) -> void:
	paytable_rows.clear()
	paytable_amount_labels.clear()
	paytable_multipliers.clear()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 156)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.078, 0.039, 0.016, 0.8)
	ps.border_color = COLOR_GOLD_DARK
	ps.border_width_left = 1; ps.border_width_right = 1
	ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.corner_radius_top_left = 6; ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6; ps.corner_radius_bottom_right = 6
	ps.content_margin_left = 4; ps.content_margin_right = 4
	ps.content_margin_top = 3; ps.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var pbox := VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 1)
	panel.add_child(pbox)

	var hands := [
		["RoyalFlush", "ROYAL FLUSH", 1000, Color(1.0, 0.847, 0.302)],
		["StraightFlush", "STRAIGHT FLUSH", 75, COLOR_RED],
		["FourOfAKind", "FOUR OF A KIND", 15, COLOR_GREEN_DIM],
		["FullHouse", "FULL HOUSE", 12, Color(0.498, 0.843, 1.0)],
		["Flush", "FLUSH", 10, COLOR_RED],
		["Straight", "STRAIGHT", 8, COLOR_WHITE],
		["ThreeOfAKind", "THREE OF A KIND", 3, COLOR_BLUE],
		["TwoPair", "TWO PAIR", 2, COLOR_WHITE],
	]
	for hand in hands:
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 15)
		var rps := StyleBoxFlat.new()
		rps.bg_color = Color(0, 0, 0, 0)
		row_panel.add_theme_stylebox_override("panel", rps)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row_panel.add_child(row)
		var name_l := _make_label(hand[1], 12, hand[3])
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		row.add_child(name_l)
		var amount_l := _make_label("0", 12, hand[3], HORIZONTAL_ALIGNMENT_RIGHT)
		amount_l.custom_minimum_size = Vector2(98, 0)
		row.add_child(amount_l)
		paytable_rows[str(hand[0])] = row_panel
		paytable_amount_labels[str(hand[0])] = amount_l
		paytable_multipliers[str(hand[0])] = int(hand[2])
		pbox.add_child(row_panel)

	var fh_rank_row := HBoxContainer.new()
	fh_rank_row.add_theme_constant_override("separation", 4)
	pbox.add_child(fh_rank_row)
	full_house_rank_label = _make_label(_full_house_rank_text(), 12, Color(0.498, 0.843, 1.0))
	fh_rank_row.add_child(full_house_rank_label)
	full_house_jackpot_label = _make_label("0", 12, Color(0.498, 0.843, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	full_house_jackpot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh_rank_row.add_child(full_house_jackpot_label)

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
	card_area_panel = Panel.new()
	var cps := StyleBoxFlat.new()
	cps.bg_color = Color(0.02, 0.01, 0.005, 0.6)
	cps.border_color = COLOR_GOLD_DARK
	cps.border_width_left = 1; cps.border_width_right = 1
	cps.border_width_top = 1; cps.border_width_bottom = 1
	cps.corner_radius_top_left = 8; cps.corner_radius_top_right = 8
	cps.corner_radius_bottom_left = 8; cps.corner_radius_bottom_right = 8
	card_area_panel.add_theme_stylebox_override("panel", cps)
	card_area_panel.custom_minimum_size = Vector2(0, CARD_AREA_MIN_HEIGHT)
	parent.add_child(card_area_panel)

	card_container = HBoxContainer.new()
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	card_container.add_theme_constant_override("separation", CARD_GAP)
	card_area_panel.add_child(card_container)

	idle_title_label = _make_label(IDLE_TITLE_TEXT, 42, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	idle_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	idle_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	idle_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	idle_title_label.add_theme_constant_override("shadow_outline_size", 4)
	idle_title_label.visible = false
	card_area_panel.add_child(idle_title_label)

	for index in range(5):
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 2)

		var tr := TextureRect.new()
		tr.custom_minimum_size = CARD_SIZE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_STOP
		tr.gui_input.connect(_on_card_gui_input.bind(index))
		slot.add_child(tr)

		var hold_label := _make_label("", 10, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		slot.add_child(hold_label)

		var slot_state := {
			"rect": tr,
			"hold_label": hold_label,
			"tween": null,
			"displayed_code": "",
			"pending_code": ""
		}
		cards_texture_rects.append(slot_state)
		_stage_card_back(slot_state, "", false)
		card_container.add_child(slot)

func _build_win_display(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	win_slot_label = _make_label("", 12, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	row.add_child(win_slot_label)
	win_amount_label = _make_label("", 22, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	win_amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	win_amount_label.add_theme_constant_override("shadow_offset_x", 2)
	win_amount_label.add_theme_constant_override("shadow_offset_y", 2)
	win_amount_label.add_theme_constant_override("shadow_outline_size", 2)
	row.add_child(win_amount_label)

func _build_machine_info(parent: Node) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 96)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.078, 0.039, 0.016, 0.5)
	ps.border_color = COLOR_GOLD_DARK
	ps.border_width_left = 1; ps.border_width_right = 1
	ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.corner_radius_top_left = 6; ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6; ps.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)
	machine_info_bg = panel

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	margin.add_child(rows)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	rows.add_child(hbox)

	machine_serie_label = _make_label("SERIE 0", 11, COLOR_GREEN)
	hbox.add_child(machine_serie_label)
	machine_kent_label = _make_label("KENT /3 : 0", 11, COLOR_GREEN)
	hbox.add_child(machine_kent_label)
	machine_serial_label = _make_label("S/N: 0", 12, COLOR_GREEN)
	machine_serial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	machine_serial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(machine_serial_label)

	var jp_row := HBoxContainer.new()
	jp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	jp_row.add_theme_constant_override("separation", 10)
	jp_row.custom_minimum_size = Vector2(0, 34)
	rows.add_child(jp_row)

	jackpot_counter_panels.clear()
	for slot in [["*", "4k-a", COLOR_GREEN_DIM], ["SF", "sf", COLOR_RED], ["*", "4k-b", COLOR_GREEN_DIM]]:
		var counter_panel := Panel.new()
		counter_panel.custom_minimum_size = Vector2(150, 34)
		var cps := StyleBoxFlat.new()
		cps.bg_color = Color(0, 0, 0, 0)
		counter_panel.add_theme_stylebox_override("panel", cps)
		var counter_box := VBoxContainer.new()
		counter_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		counter_box.alignment = BoxContainer.ALIGNMENT_CENTER
		counter_box.add_theme_constant_override("separation", 1)
		counter_panel.add_child(counter_box)
		var tag := _make_label(slot[0], 10, slot[2], HORIZONTAL_ALIGNMENT_CENTER)
		counter_box.add_child(tag)
		var val := _make_label("0", 14, COLOR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		counter_box.add_child(val)
		jackpot_counters[str(slot[1])] = val
		jackpot_counter_panels[str(slot[1])] = counter_panel
		jp_row.add_child(counter_panel)

	var bonus_row := HBoxContainer.new()
	bonus_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bonus_row.add_theme_constant_override("separation", 6)
	bonus_row.custom_minimum_size = Vector2(0, 24)
	rows.add_child(bonus_row)

	bonus_message_label = _make_label("4 OF A KIND   WINS BONUS", 15, COLOR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	bonus_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_message_label.custom_minimum_size = Vector2(0, 24)
	bonus_message_label.visible = true
	bonus_row.add_child(bonus_message_label)

	bonus_stage_panel = PanelContainer.new()
	bonus_stage_panel.custom_minimum_size = Vector2(152, 26)
	bonus_row.add_child(bonus_stage_panel)

	var bonus_style := StyleBoxFlat.new()
	bonus_style.bg_color = Color(0.02, 0.01, 0.0, 0.72)
	bonus_style.border_color = COLOR_GOLD_DARK
	bonus_style.border_width_left = 1; bonus_style.border_width_right = 1
	bonus_style.border_width_top = 1; bonus_style.border_width_bottom = 1
	bonus_style.corner_radius_top_left = 4; bonus_style.corner_radius_top_right = 4
	bonus_style.corner_radius_bottom_left = 4; bonus_style.corner_radius_bottom_right = 4
	bonus_stage_panel.add_theme_stylebox_override("panel", bonus_style)

	var bonus_margin := MarginContainer.new()
	bonus_margin.add_theme_constant_override("margin_left", 4)
	bonus_margin.add_theme_constant_override("margin_right", 4)
	bonus_margin.add_theme_constant_override("margin_top", 1)
	bonus_margin.add_theme_constant_override("margin_bottom", 1)
	bonus_stage_panel.add_child(bonus_margin)

	var bonus_box := HBoxContainer.new()
	bonus_box.add_theme_constant_override("separation", 4)
	bonus_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bonus_margin.add_child(bonus_box)

	bonus_stage_card = TextureRect.new()
	bonus_stage_card.custom_minimum_size = Vector2(18, 24)
	bonus_stage_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bonus_stage_card.stretch_mode = TextureRect.STRETCH_SCALE
	bonus_box.add_child(bonus_stage_card)

	var bonus_texts := VBoxContainer.new()
	bonus_texts.add_theme_constant_override("separation", 0)
	bonus_texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_box.add_child(bonus_texts)
	bonus_stage_label = _make_label("FREE GAMES", 8, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	bonus_texts.add_child(bonus_stage_label)
	bonus_stage_amount_label = _make_label("BONUS 0", 8, COLOR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	bonus_texts.add_child(bonus_stage_amount_label)

func _build_du_info(parent: Node) -> void:
	du_info_panel = VBoxContainer.new()
	du_info_panel.visible = false
	du_info_panel.add_theme_constant_override("separation", 2)
	parent.add_child(du_info_panel)

	du_label_node = _make_label("HI LO GAMBLE", 14, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	du_info_panel.add_child(du_label_node)

	du_trail_container = HBoxContainer.new()
	du_trail_container.name = "DoubleUpDeckRow"
	du_trail_container.alignment = BoxContainer.ALIGNMENT_CENTER
	du_trail_container.add_theme_constant_override("separation", 7)
	du_info_panel.add_child(du_trail_container)

	du_cards.clear()
	for index in range(DOUBLE_UP_BOARD_SLOT_COUNT):
		var slot := VBoxContainer.new()
		slot.name = "DoubleUpDeckSlot%d" % index
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override("separation", 1)
		var slot_label := _make_label("", 8, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
		slot_label.custom_minimum_size = Vector2(0, 14)
		slot.add_child(slot_label)
		var slot_rect := TextureRect.new()
		slot_rect.custom_minimum_size = DU_TRAIL_CARD_SIZE
		slot_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_rect.stretch_mode = TextureRect.STRETCH_SCALE
		slot.add_child(slot_rect)
		du_trail_container.add_child(slot)
		du_cards.append({ "label": slot_label, "rect": slot_rect })
		if index == 0:
			du_dealer_label = slot_label
			du_dealer_rect = slot_rect
		elif index == 1:
			du_challenger_label = slot_label
			du_challenger_rect = slot_rect

	var du_infos := HBoxContainer.new()
	du_infos.alignment = BoxContainer.ALIGNMENT_CENTER
	du_infos.add_theme_constant_override("separation", 8)
	du_info_panel.add_child(du_infos)

	du_infos.add_child(_make_label("ACE COUNTS", 9, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER))
	du_guess_node = _make_label("HI OR LO", 9, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	du_infos.add_child(du_guess_node)
	du_lucky_node = _make_label("5♠ NEVER LOSE", 9, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	du_infos.add_child(du_lucky_node)
	du_infos.add_child(_make_label("WHEN BUYING", 9, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER))

	du_switch_node = _make_label("", 9, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	du_info_panel.add_child(du_switch_node)

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

	for tup in [["ADMIN PANEL", null], ["AGENTS", _on_admin_agents], ["USERS", _on_admin_users], ["MACHINES", _on_admin_machines], ["CLOSE", _on_admin_close]]:
		if tup[0] == "ADMIN PANEL":
			var l := _make_label(tup[0], 18, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tabs.add_child(l)
		else:
			var b := _make_button(tup[0], 38, COLOR_PANEL_BG.lightened(0.15), COLOR_CREAM, COLOR_GOLD_DARK)
			if tup[1] != null: b.pressed.connect(tup[1])
			tabs.add_child(b)

	admin_user_search_row = HBoxContainer.new()
	admin_user_search_row.add_theme_constant_override("separation", 6)
	admin_user_search_row.visible = false
	admin_screen.add_child(admin_user_search_row)
	admin_search_edit = _make_admin_edit("SEARCH USERNAME")
	admin_user_search_row.add_child(admin_search_edit)
	var sb := _make_button("SEARCH", 34, COLOR_PANEL_BG.lightened(0.2), COLOR_GOLD, COLOR_GOLD_DARK)
	sb.pressed.connect(_on_admin_search)
	admin_user_search_row.add_child(sb)

	admin_agent_tools = VBoxContainer.new()
	admin_agent_tools.add_theme_constant_override("separation", 4)
	admin_screen.add_child(admin_agent_tools)

	var agent_create_row := HBoxContainer.new()
	agent_create_row.add_theme_constant_override("separation", 5)
	admin_agent_tools.add_child(agent_create_row)
	admin_agent_name_edit = _make_admin_edit("AGENT NAME", 116)
	agent_create_row.add_child(admin_agent_name_edit)
	admin_agent_code_edit = _make_admin_edit("CODE", 66)
	agent_create_row.add_child(admin_agent_code_edit)
	admin_agent_phone_edit = _make_admin_edit("PHONE", 96)
	agent_create_row.add_child(admin_agent_phone_edit)
	var create_agent_button := _make_button("CREATE", 34, COLOR_PANEL_BG.lightened(0.2), COLOR_GOLD, COLOR_GOLD_DARK)
	create_agent_button.pressed.connect(_on_admin_create_agent)
	agent_create_row.add_child(create_agent_button)

	var agent_credit_row := HBoxContainer.new()
	agent_credit_row.add_theme_constant_override("separation", 5)
	admin_agent_tools.add_child(agent_credit_row)
	admin_agent_credit_edit = _make_admin_edit("CREDIT", 110)
	admin_agent_credit_edit.text = "100000"
	agent_credit_row.add_child(admin_agent_credit_edit)
	var load_credit_button := _make_button("LOAD", 34, COLOR_PANEL_BG.lightened(0.2), COLOR_GREEN, COLOR_GREEN_DIM)
	load_credit_button.pressed.connect(_on_admin_load_agent_credit)
	agent_credit_row.add_child(load_credit_button)
	var refresh_agent_button := _make_button("REFRESH", 34, COLOR_PANEL_BG.lightened(0.2), COLOR_CREAM, COLOR_GOLD_DARK)
	refresh_agent_button.pressed.connect(_on_admin_agents)
	agent_credit_row.add_child(refresh_agent_button)

	admin_agents_list = VBoxContainer.new()
	admin_agents_list.add_theme_constant_override("separation", 2)
	admin_screen.add_child(admin_agents_list)

	admin_users_list = VBoxContainer.new()
	admin_users_list.add_theme_constant_override("separation", 2)
	admin_users_list.visible = false
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
	if kind in ["admin_users", "admin_users_search", "admin_machines", "admin_agents", "admin_agent_create", "admin_agent_load_credit", "admin_agent_assign_user"]:
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
	elif kind == "admin_agents":
		admin_agent_list = data if typeof(data) == TYPE_ARRAY else []
		if admin_selected_agent_id == 0 and not admin_agent_list.is_empty():
			var first: Dictionary = admin_agent_list[0] if typeof(admin_agent_list[0]) == TYPE_DICTIONARY else {}
			admin_selected_agent_id = int(first.get("id", 0))
		_refresh_admin_agents()
	elif kind == "admin_agent_create" or kind == "admin_agent_load_credit":
		var agent: Dictionary = data if typeof(data) == TYPE_DICTIONARY else {}
		admin_selected_agent_id = int(agent.get("id", admin_selected_agent_id))
		recovery_label.text = "Admin agent saved."
		if not access_token.is_empty(): api.get_admin_agents()
	elif kind == "admin_agent_assign_user":
		recovery_label.text = "Admin user assigned to agent."
		if not access_token.is_empty(): api.get_admin_agents()

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
			auto_holds_cancelled = false
		configured_machine_id = store.machine_id(configured_machine_id)
		selected_bet = clampi(selected_bet, max(1, store.min_bet()), max(store.min_bet(), store.max_bet()))
		if selected_bet == 0: selected_bet = max(1, store.stake())
		_refresh_ui()

# ─── UI refresh ───
func _refresh_ui() -> void:
	_refresh_auth_panel()
	title_label.text = "%s\n%s" % [store.machine_name(), str(store.snapshot.get("variant", {}).get("display_name", "Lucky5 Classic"))]
	_refresh_credit_display()
	var game_state := store.game_state()
	message_label.text = store.message()
	if game_state == "hold" and local_hold_indexes.is_empty() and not auto_holds_cancelled and not store.advised_hold_indexes().is_empty():
		message_label.text = "AUTO-HOLD SUGGESTED - DRAW OR ADJUST"
	if access_token.is_empty():
		recovery_label.text = "LOGIN: %s" % auth_status
	else:
		recovery_label.text = "" if store.commands_allowed() else "RECOVERY: %s" % store.recovery_message()
	bet_label.text = "BET %s" % _format_amount(selected_bet)

	if last_game_state != game_state and game_state != "hold":
		local_hold_indexes.clear()
	last_game_state = game_state

	var du_data: Dictionary = store.snapshot.get("double_up", {})
	var du_active := bool(du_data.get("active", false))
	_maybe_auto_start_double_up(game_state, du_active)
	_refresh_card_area_layout(du_active)

	_refresh_cards(game_state, du_active)
	_refresh_du_panel(du_data, du_active)
	_refresh_jackpots()
	_refresh_machine_info()
	_refresh_win_display()
	_refresh_lucky5_banner()
	admin_screen.visible = active_screen == "admin"
	if menu_overlay != null:
		menu_overlay.visible = menu_open and active_screen == "game"

	for id in action_buttons.keys():
		var button: Button = action_buttons[id]
		button.disabled = not _is_action_enabled(id)
		if id == "deal_draw" and not _button_uses_asset(button):
			button.text = "DEAL\nDRAW"

	var held_indexes := _visual_hold_indexes()
	for index in range(hold_buttons.size()):
		var hold_button: Button = hold_buttons[index]
		var held := held_indexes.has(index)
		hold_button.disabled = not _is_action_enabled("hold_%d" % index)
		hold_button.text = "HELD" if held else ("" if _button_uses_asset(hold_button) else "HOLD")

func _refresh_card_area_layout(du_active: bool) -> void:
	if card_area_panel == null:
		return
	card_area_panel.visible = not du_active
	card_area_panel.custom_minimum_size = Vector2(0, 0 if du_active else CARD_AREA_MIN_HEIGHT)

func _refresh_cards(game_state: String, du_active: bool) -> void:
	var cards := store.cards()
	if game_state == "drawn" or game_state == "win": cards = store.result_cards()
	var previous_codes := _get_displayed_card_codes()
	var held_indexes := _visual_hold_indexes()
	deal_queue.clear()
	deal_queue_index = 0
	if deal_timer != null:
		deal_timer.stop()

	var is_blank_idle := game_state == "idle" and not du_active and cards.is_empty()
	_sync_idle_fh_timer(is_blank_idle)
	var show_idle_title := is_blank_idle and not idle_fh_rank_revealed
	var show_idle_rank_card := is_blank_idle and idle_fh_rank_revealed
	if idle_title_label != null:
		idle_title_label.visible = show_idle_title
	if card_container != null:
		card_container.visible = not show_idle_title

	for index in range(5):
		var slot: Dictionary = cards_texture_rects[index]
		if show_idle_title:
			_stage_empty_card_slot(slot)
			continue
		if show_idle_rank_card and index == 2:
			var rank_code := _full_house_rank_card_code()
			if rank_code.length() >= 2:
				var tex := _card_texture_from_code(rank_code)
				slot["rect"].texture = tex if tex != null else null
				slot["rect"].modulate = Color(1, 1, 1, 1)
			slot["hold_label"].text = "FH"
			slot["displayed_code"] = rank_code
			slot["pending_code"] = ""
			continue
		if show_idle_rank_card:
			_stage_empty_card_slot(slot)
			continue
		if index < cards.size() and typeof(cards[index]) == TYPE_DICTIONARY:
			var card: Dictionary = cards[index]
			var code: String = card.get("code", "")
			var held := held_indexes.has(index) or bool(card.get("held", false))
			slot["hold_label"].text = "HELD" if held else ""

			if code.length() >= 2:
				var previous_code: String = previous_codes[index] if index < previous_codes.size() else ""
				var pending_code := str(slot.get("pending_code", ""))
				if previous_code != code:
					if _should_draw_replace_card(game_state, previous_code, code, held):
						slot["pending_code"] = code
						_queue_card_draw_replacement(index, code, held)
					else:
						if pending_code != code:
							_stage_card_back(slot, code, held)
						_queue_card_reveal(index, code, held)
				else:
					slot["pending_code"] = ""
					slot["rect"].modulate = Color(1, 1, 1, 1)
			else:
				_stage_card_back(slot, "", false)
		else:
			_stage_card_back(slot, "", false)
			slot["hold_label"].text = ""

	if not deal_queue.is_empty():
		_process_deal_queue()

func _visual_hold_indexes() -> Array:
	var indexes := _normalized_hold_indexes(store.held_indexes())
	for index in local_hold_indexes:
		if not indexes.has(index):
			indexes.append(index)
	if indexes.is_empty() and not auto_holds_cancelled:
		indexes = _normalized_hold_indexes(store.advised_hold_indexes())
	indexes.sort()
	return indexes

func _draw_hold_indexes() -> Array:
	var indexes := _normalized_hold_indexes(local_hold_indexes)
	if indexes.is_empty():
		indexes = _normalized_hold_indexes(store.held_indexes())
	if indexes.is_empty() and not auto_holds_cancelled:
		indexes = _normalized_hold_indexes(store.advised_hold_indexes())
	return indexes

func _editable_hold_baseline() -> Array:
	if auto_holds_cancelled:
		return []
	var baseline := _normalized_hold_indexes(local_hold_indexes)
	if baseline.is_empty():
		baseline = _normalized_hold_indexes(store.held_indexes())
	if baseline.is_empty():
		baseline = _normalized_hold_indexes(store.advised_hold_indexes())
	return baseline

func _normalized_hold_indexes(values: Array) -> Array:
	var indexes := []
	for value in values:
		var index := store._to_int(value)
		if index >= 0 and index < 5 and not indexes.has(index):
			indexes.append(index)
	indexes.sort()
	return indexes

func _sync_idle_fh_timer(is_blank_idle: bool) -> void:
	if not is_blank_idle:
		idle_fh_rank_revealed = false
		if idle_fh_timer != null:
			idle_fh_timer.stop()
		if idle_title_label != null:
			idle_title_label.visible = false
		if card_container != null:
			card_container.visible = true
		return
	if idle_fh_rank_revealed:
		return
	if idle_fh_timer != null and idle_fh_timer.is_stopped():
		idle_fh_timer.start()

func _on_idle_fh_timer_timeout() -> void:
	idle_fh_rank_revealed = true
	_refresh_ui()

func _maybe_auto_start_double_up(game_state: String, du_active: bool) -> void:
	if du_active or _has_pending_command() or access_token.is_empty():
		return
	if not (game_state in ["win", "drawn", "result"]):
		return
	var evaluation: Dictionary = store.snapshot.get("evaluation", {})
	if not bool(evaluation.get("double_up_available", false)):
		return
	var round_id := store.current_round_id()
	if round_id.is_empty() or auto_double_up_round_ids.has(round_id):
		return
	auto_double_up_round_ids.append(round_id)
	if auto_double_up_round_ids.size() > 32:
		auto_double_up_round_ids.remove_at(0)
	call_deferred("_auto_start_double_up", round_id)

func _auto_start_double_up(round_id: String) -> void:
	if round_id.is_empty() or _has_pending_command() or access_token.is_empty():
		return
	if store.current_round_id() != round_id:
		return
	var game_state := store.game_state()
	if not (game_state in ["win", "drawn", "result"]):
		return
	var du_data: Dictionary = store.snapshot.get("double_up", {})
	if bool(du_data.get("active", false)):
		return
	_send_command("double_up_start", {"round_id": round_id})

func _queue_card_reveal(index: int, code: String, held: bool) -> void:
	var tex := _card_texture_from_code(code)
	if tex == null:
		return
	deal_queue.append({
		"mode": "deal",
		"index": index,
		"code": code,
		"texture": tex,
		"held": held
	})

func _queue_card_draw_replacement(index: int, code: String, held: bool) -> void:
	var tex := _card_texture_from_code(code)
	if tex == null:
		return
	deal_queue.append({
		"mode": "draw",
		"index": index,
		"code": code,
		"texture": tex,
		"held": held
	})

func _should_draw_replace_card(game_state: String, previous_code: String, next_code: String, held: bool) -> bool:
	if held or previous_code.is_empty() or next_code.is_empty() or previous_code == next_code:
		return false
	return game_state in ["drawn", "win", "result"]

func _card_texture_from_code(code: String) -> Texture2D:
	if code.length() < 2:
		return null
	var rank := code.substr(0, code.length() - 1)
	var suit := code.substr(code.length() - 1, 1)
	return CardSkin_Lucky5.card_texture(rank, suit)

func _card_back_texture(held: bool) -> Texture2D:
	return CardSkin_Lucky5.back_texture(held)

func _stage_card_back(slot: Dictionary, code: String, held: bool) -> void:
	if slot["tween"] != null and slot["tween"].is_valid():
		slot["tween"].kill()
	slot["tween"] = null
	slot["rect"].texture = _card_back_texture(held)
	var rect: TextureRect = slot["rect"]
	rect.modulate = Color(1, 1, 1, 1)
	rect.scale = Vector2(1.0, 1.0)
	slot["pending_code"] = code
	if code.is_empty():
		slot["displayed_code"] = ""

func _stage_empty_card_slot(slot: Dictionary) -> void:
	if slot["tween"] != null and slot["tween"].is_valid():
		slot["tween"].kill()
	slot["tween"] = null
	var rect: TextureRect = slot["rect"]
	rect.texture = null
	rect.modulate = Color(1, 1, 1, 0)
	rect.scale = Vector2(1.0, 1.0)
	slot["hold_label"].text = ""
	slot["displayed_code"] = ""
	slot["pending_code"] = ""

func _show_queued_card(reveal: Dictionary) -> void:
	var index := int(reveal.get("index", -1))
	if index < 0 or index >= cards_texture_rects.size():
		return
	if str(reveal.get("mode", "deal")) == "draw":
		_show_draw_replacement(index, reveal)
		return
	var slot: Dictionary = cards_texture_rects[index]
	var rect: TextureRect = slot["rect"]
	var code: String = str(reveal.get("code", ""))
	rect.texture = reveal.get("texture", null)
	slot["displayed_code"] = code
	slot["pending_code"] = ""
	slot["hold_label"].text = "HELD" if bool(reveal.get("held", false)) else ""
	_animate_card_deal(index)

func _show_draw_replacement(index: int, reveal: Dictionary) -> void:
	var slot: Dictionary = cards_texture_rects[index]
	var rect: TextureRect = slot["rect"]
	var code: String = str(reveal.get("code", ""))
	var texture: Texture2D = reveal.get("texture", null)
	if texture == null or code.length() < 2:
		return

	if slot["tween"] != null and slot["tween"].is_valid():
		slot["tween"].kill()
	slot["tween"] = null

	rect.pivot_offset = rect.custom_minimum_size * 0.5
	var base_position := rect.position
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "modulate", Color(1, 1, 1, 0), DRAW_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rect, "position", base_position + Vector2(0, 48), DRAW_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rect, "scale", Vector2(0.92, 0.92), DRAW_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(Callable(self, "_finish_card_draw_replacement").bind(index, code, texture, bool(reveal.get("held", false)), base_position))
	slot["tween"] = tw

func _finish_card_draw_replacement(index: int, code: String, texture: Texture2D, held: bool, base_position: Vector2) -> void:
	if index < 0 or index >= cards_texture_rects.size():
		return
	var slot: Dictionary = cards_texture_rects[index]
	var rect: TextureRect = slot["rect"]
	slot["tween"] = null
	rect.texture = texture
	rect.position = base_position + Vector2(0, -38)
	rect.scale = Vector2(0.88, 0.88)
	rect.modulate = Color(1, 1, 1, 0)
	slot["displayed_code"] = code
	slot["pending_code"] = ""
	slot["hold_label"].text = "HELD" if held else ""
	_animate_card_draw_in(index, base_position)

func _animate_card_draw_in(index: int, base_position: Vector2) -> void:
	var slot: Dictionary = cards_texture_rects[index]
	var rect: TextureRect = slot["rect"]

	if slot["tween"] != null and slot["tween"].is_valid():
		slot["tween"].kill()
	slot["tween"] = null

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "modulate", Color(1, 1, 1, 1), DRAW_IN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "position", base_position, DRAW_IN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "scale", Vector2(1.03, 1.03), DRAW_IN_DURATION * 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(rect, "scale", Vector2(1.0, 1.0), DRAW_IN_DURATION * 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slot["tween"] = tw

func _get_displayed_card_codes() -> Array:
	var result: Array = []
	for slot in cards_texture_rects:
		result.append(str(slot.get("displayed_code", "")))
	return result

func _animate_card_deal(index: int) -> void:
	var slot: Dictionary = cards_texture_rects[index]
	var rect: TextureRect = slot["rect"]

	if slot["tween"] != null and slot["tween"].is_valid():
		slot["tween"].kill()
	slot["tween"] = null

	rect.modulate = Color(1, 1, 1, 0)
	rect.pivot_offset = rect.custom_minimum_size * 0.5
	var base_position := rect.position
	rect.position = base_position + Vector2(0, -58)
	rect.scale = Vector2(0.82, 0.82)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "modulate", Color(1, 1, 1, 1), DEAL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "position", base_position, DEAL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "scale", Vector2(1.04, 1.04), DEAL_DURATION * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(rect, "scale", Vector2(1.0, 1.0), DEAL_DURATION * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slot["tween"] = tw

func _refresh_du_panel(du_data: Dictionary, du_active: bool) -> void:
	du_info_panel.visible = du_active
	if not du_active:
		if du_shuffle_timer != null:
			du_shuffle_timer.stop()
		if du_promote_timer != null:
			du_promote_timer.stop()
		_clear_du_board()
		du_pending_promote_dealer = ""
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

	var dealer_changed := not dealer_code.is_empty() and _prev_dealer_code != "" and _prev_dealer_code != dealer_code
	var challenger_changed := not challenger_code.is_empty() and _prev_challenger_code != challenger_code
	var inferred_win_reveal := challenger_code.is_empty() and dealer_changed
	var board_dealer_code := _prev_dealer_code if inferred_win_reveal else dealer_code
	var board_challenger_code := dealer_code if inferred_win_reveal else challenger_code
	var board_status := "Win" if inferred_win_reveal else status

	_prepare_du_board(du_data, board_dealer_code, board_challenger_code, board_status)

	if inferred_win_reveal:
		if du_promote_timer != null:
			du_promote_timer.stop()
		_start_du_card_shuffle(board_dealer_code, board_challenger_code)
		_queue_du_dealer_promotion(board_challenger_code)
	elif challenger_code.is_empty():
		if du_promote_timer != null:
			du_promote_timer.stop()
		du_pending_promote_dealer = ""
		_set_du_card_texture(du_dealer_rect, dealer_code)
		if du_shuffle_timer == null or du_shuffle_timer.is_stopped() or not du_shuffle_target_challenger.is_empty():
			_start_du_card_shuffle(dealer_code, "")
	elif dealer_changed or challenger_changed:
		_start_du_card_shuffle(dealer_code, challenger_code)
		if challenger_changed and _du_should_promote_after_reveal(status, challenger_code):
			_queue_du_dealer_promotion(challenger_code)
	else:
		if du_shuffle_timer != null and not du_shuffle_timer.is_stopped():
			du_shuffle_timer.stop()
		_set_du_card_texture(du_dealer_rect, dealer_code)
		_set_du_card_texture(du_challenger_rect, challenger_code)

	_prev_dealer_code = dealer_code
	_prev_challenger_code = challenger_code

	var is_lucky5 := bool(du_data.get("is_lucky5_active", false))
	var is_no_lose := bool(du_data.get("is_no_lose_active", false))
	du_lucky_node.text = "5♠ NEVER LOSE"
	du_lucky_node.add_theme_color_override("font_color", COLOR_GREEN if is_lucky5 or is_no_lose else COLOR_BLUE)
	du_guess_node.text = "HI OR LO"

func _prepare_du_board(du_data: Dictionary, dealer_code: String, challenger_code: String, status: String) -> void:
	_clear_du_board()

	_refresh_du_trail(du_data, dealer_code, challenger_code, status)

func _refresh_du_trail(du_data: Dictionary, dealer_code: String, challenger_code: String, status: String) -> void:
	var trail_codes := _du_visible_deck_codes(du_data, dealer_code, challenger_code, du_cards.size())
	var dealer_index := _du_last_code_index(trail_codes, dealer_code)
	var challenger_index := _du_last_code_index(trail_codes, challenger_code)
	var shuffle_index := -1
	if challenger_code.is_empty() and dealer_code.length() >= 2:
		shuffle_index = min(trail_codes.size(), du_cards.size() - 1)

	for index in range(du_cards.size()):
		if index < trail_codes.size():
			var code := str(trail_codes[index])
			var label_text := "DEALER" if index == dealer_index else "HIT"
			if index == challenger_index:
				label_text = _du_result_label(status)
			_set_du_board_slot(index, code, label_text, _is_lucky_du_card(du_data, code))
			if index == dealer_index:
				_set_du_dealer_slot(index)
			if index == challenger_index:
				_set_du_challenger_slot(index)
		elif index == shuffle_index:
			_set_du_board_back(index, "BIG / SMALL ?", 1.0)
			_set_du_challenger_slot(index)
		else:
			_set_du_board_back(index, "", 0.18)

	if dealer_index < 0 and not trail_codes.is_empty():
		_set_du_dealer_slot(0)
		_set_du_board_slot(0, str(trail_codes[0]), "DEALER", _is_lucky_du_card(du_data, str(trail_codes[0])))
	if du_challenger_rect == null and du_cards.size() > 1:
		_set_du_challenger_slot(1)

func _du_visible_deck_codes(du_data: Dictionary, dealer_code: String, challenger_code: String, max_count: int) -> Array:
	var result := _du_visible_trail_codes(du_data, "", max_count)
	if dealer_code.length() >= 2 and (result.is_empty() or str(result[result.size() - 1]) != dealer_code):
		result.append(dealer_code)
	if challenger_code.length() >= 2 and (result.is_empty() or str(result[result.size() - 1]) != challenger_code):
		result.append(challenger_code)
	while result.size() > max_count:
		result.remove_at(0)
	return result

func _du_visible_trail_codes(du_data: Dictionary, dealer_code: String, max_count: int) -> Array:
	var result: Array = []
	if max_count <= 0:
		return result

	var trail_source: Variant = du_data.get("card_trail", [])
	if typeof(trail_source) != TYPE_ARRAY:
		return result

	var codes: Array = []
	for entry in trail_source:
		var code := _du_entry_code(entry)
		if code.length() >= 2:
			codes.append(code)

	if dealer_code.length() >= 2 and not codes.is_empty() and str(codes[codes.size() - 1]) == dealer_code:
		codes.remove_at(codes.size() - 1)

	var start_index := 0
	if codes.size() > max_count:
		var carry_step: int = max(1, max_count - 1)
		var pages := int(ceil(float(codes.size() - max_count) / float(carry_step)))
		start_index = pages * carry_step

	var limit: int = min(codes.size(), start_index + max_count)
	for i in range(start_index, limit):
		result.append(str(codes[i]))
	return result

func _du_last_code_index(codes: Array, target_code: String) -> int:
	if target_code.length() < 2:
		return -1
	for index in range(codes.size() - 1, -1, -1):
		if str(codes[index]) == target_code:
			return index
	return -1

func _du_entry_code(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		var entry_dict: Dictionary = entry
		var card: Variant = entry_dict.get("card", entry_dict)
		if typeof(card) == TYPE_DICTIONARY:
			return str(card.get("code", ""))
		return str(entry_dict.get("code", ""))
	if typeof(entry) == TYPE_STRING:
		return str(entry)
	return ""

func _du_result_label(status: String) -> String:
	var normalized := status.to_upper()
	if normalized.find("LOSE") >= 0:
		return "LOSE"
	if normalized.find("SAFE") >= 0:
		return "SAFE"
	if normalized.find("WIN") >= 0 or normalized.find("LUCKY") >= 0:
		return "WIN"
	return "BIG / SMALL ?"

func _du_should_promote_after_reveal(status: String, challenger_code: String) -> bool:
	if challenger_code.length() < 2:
		return false
	var normalized := status.to_upper()
	return normalized.find("LOSE") < 0 and normalized.find("LOST") < 0

func _queue_du_dealer_promotion(next_dealer_code: String) -> void:
	if next_dealer_code.length() < 2:
		return
	du_pending_promote_dealer = next_dealer_code
	if du_promote_timer != null:
		du_promote_timer.stop()
		du_promote_timer.wait_time = DU_REVEAL_SETTLE_SECONDS
		du_promote_timer.start()

func _on_du_promote_timeout() -> void:
	if du_pending_promote_dealer.length() < 2:
		return
	var du_data: Dictionary = store.snapshot.get("double_up", {})
	if not bool(du_data.get("active", false)):
		du_pending_promote_dealer = ""
		return
	if not _du_should_promote_after_reveal(str(du_data.get("status", "")), du_pending_promote_dealer):
		du_pending_promote_dealer = ""
		return
	_start_du_card_shuffle(du_pending_promote_dealer, "")
	du_pending_promote_dealer = ""

func _is_lucky_du_card(du_data: Dictionary, code: String) -> bool:
	return code == "5S" and (bool(du_data.get("is_lucky5_active", false)) or bool(du_data.get("is_no_lose_active", false)))

func _clear_du_board() -> void:
	for index in range(du_cards.size()):
		_set_du_board_back(index, "", 0.34)
	du_dealer_rect = null
	du_dealer_label = null
	du_challenger_rect = null
	du_challenger_label = null
	if du_dealer_label != null:
		du_dealer_label.text = "DEALER"
		du_dealer_label.add_theme_color_override("font_color", COLOR_BLUE)
	if du_dealer_rect != null:
		du_dealer_rect.texture = _card_back_texture(false)
		du_dealer_rect.modulate = Color(1, 1, 1, 0.34)
		du_dealer_rect.scale = Vector2(1.0, 1.0)
	if du_challenger_label != null:
		du_challenger_label.text = "BIG / SMALL ?"
		du_challenger_label.add_theme_color_override("font_color", COLOR_GOLD)
	if du_challenger_rect != null:
		du_challenger_rect.texture = _card_back_texture(false)
		du_challenger_rect.modulate = Color(1, 1, 1, 1.0)
		du_challenger_rect.scale = Vector2(1.0, 1.0)

func _set_du_dealer_slot(index: int) -> void:
	if index < 0 or index >= du_cards.size():
		return
	var slot: Dictionary = du_cards[index]
	du_dealer_label = slot["label"]
	du_dealer_rect = slot["rect"]

func _set_du_challenger_slot(index: int) -> void:
	if index < 0 or index >= du_cards.size():
		return
	var slot: Dictionary = du_cards[index]
	du_challenger_label = slot["label"]
	du_challenger_rect = slot["rect"]

func _set_du_board_slot(index: int, code: String, label_text: String, highlighted: bool) -> void:
	if index < 0 or index >= du_cards.size():
		return
	var slot: Dictionary = du_cards[index]
	var label: Label = slot["label"]
	var rect: TextureRect = slot["rect"]
	label.text = label_text
	label.add_theme_color_override("font_color", COLOR_GREEN if highlighted else COLOR_BLUE)
	rect.scale = Vector2(1.0, 1.0)
	_set_du_card_texture(rect, code)

func _set_du_board_back(index: int, label_text: String, alpha: float) -> void:
	if index < 0 or index >= du_cards.size():
		return
	var slot: Dictionary = du_cards[index]
	var label: Label = slot["label"]
	var rect: TextureRect = slot["rect"]
	label.text = label_text
	label.add_theme_color_override("font_color", COLOR_GOLD if not label_text.is_empty() else COLOR_BLUE)
	rect.texture = _card_back_texture(false)
	rect.modulate = Color(1, 1, 1, alpha)
	rect.scale = Vector2(1.0, 1.0)

func _animate_du_switch(new_dealer_code: String, new_player_code: String) -> void:
	_start_du_card_shuffle(new_dealer_code, new_player_code)

func _set_du_card_texture(rect: TextureRect, code: String) -> void:
	if rect == null:
		return
	var tex := _card_texture_from_code(code)
	if tex == null:
		rect.texture = null
		rect.modulate = Color(1, 1, 1, 0)
		return
	rect.texture = tex
	rect.modulate = Color(1, 1, 1, 1)

func _start_du_card_shuffle(new_dealer_code: String, new_player_code: String) -> void:
	if du_challenger_rect == null:
		return
	du_shuffle_target_dealer = new_dealer_code
	du_shuffle_target_challenger = new_player_code
	du_shuffle_ticks_remaining = DU_SHUFFLE_TICKS if new_player_code.length() >= 2 else -1
	du_shuffle_index = 0
	_set_du_card_texture(du_dealer_rect, new_dealer_code)
	du_challenger_rect.modulate = Color(1, 1, 1, 1)
	du_challenger_rect.scale = Vector2(0.92, 0.92)
	_process_du_shuffle()
	if du_shuffle_timer != null and du_shuffle_timer.is_stopped():
		du_shuffle_timer.start()

func _process_du_shuffle() -> void:
	var code: String = DU_SHUFFLE_CODES[du_shuffle_index % DU_SHUFFLE_CODES.size()]
	du_shuffle_index += 1
	_set_du_card_texture(du_challenger_rect, code)
	if du_shuffle_ticks_remaining > 0:
		du_shuffle_ticks_remaining -= 1
		if du_shuffle_ticks_remaining <= 0:
			_finish_du_card_shuffle()

func _finish_du_card_shuffle() -> void:
	if du_shuffle_timer != null:
		du_shuffle_timer.stop()
	_set_du_card_texture(du_dealer_rect, du_shuffle_target_dealer)
	_set_du_card_texture(du_challenger_rect, du_shuffle_target_challenger)
	if du_shuffle_target_challenger.length() >= 2:
		du_challenger_rect.scale = Vector2(0.92, 0.92)
		var tw := create_tween()
		tw.tween_property(du_challenger_rect, "scale", Vector2(1.0, 1.0), DU_SWITCH_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _refresh_jackpots() -> void:
	var jp: Dictionary = store.snapshot.get("jackpot", {})
	var active_4k: String = str(jp.get("active_four_of_a_kind_slot", "A"))
	_refresh_jackpot_counter("4k-a", store._to_int(jp.get("four_of_a_kind_a", 0)))
	_refresh_jackpot_counter("sf", store._to_int(jp.get("straight_flush", 0)))
	_refresh_jackpot_counter("4k-b", store._to_int(jp.get("four_of_a_kind_b", 0)))
	_set_jackpot_counter_active("4k-a", active_4k == "A")
	_set_jackpot_counter_active("4k-b", active_4k == "B")
	_refresh_paytable_values()
	_refresh_paytable_highlights()
	_refresh_bonus_stage()

func _refresh_jackpot_counter(slot_key: String, target_value: int) -> void:
	if not jackpot_counters.has(slot_key):
		return
	var target: int = max(0, target_value)
	if not displayed_jackpots.has(slot_key):
		displayed_jackpots[slot_key] = target
		jackpot_counter_targets[slot_key] = target
		_set_jackpot_counter_display(float(target), slot_key)
		return
	var current_target := int(jackpot_counter_targets.get(slot_key, displayed_jackpots.get(slot_key, 0)))
	if current_target == target:
		return
	_animate_jackpot_counter(slot_key, int(displayed_jackpots.get(slot_key, current_target)), target)

func _animate_jackpot_counter(slot_key: String, from_value: int, to_value: int) -> void:
	if jackpot_counter_tweens.has(slot_key):
		var existing: Tween = jackpot_counter_tweens[slot_key]
		if existing != null and existing.is_valid():
			existing.kill()
	jackpot_counter_targets[slot_key] = to_value
	var duration := JACKPOT_DRAIN_DURATION if to_value < from_value else JACKPOT_TRICKLE_DURATION
	var tween := create_tween()
	jackpot_counter_tweens[slot_key] = tween
	tween.tween_method(Callable(self, "_set_jackpot_counter_display").bind(slot_key), float(from_value), float(to_value), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_jackpot_counter_display(value: float, slot_key: String) -> void:
	var amount: int = max(0, int(round(value)))
	displayed_jackpots[slot_key] = amount
	var label: Label = jackpot_counters.get(slot_key, null)
	if label != null:
		label.text = _format_amount(amount)

func _set_jackpot_counter_active(slot_key: String, active: bool) -> void:
	var counter_panel: Panel = jackpot_counter_panels.get(slot_key, null)
	if counter_panel == null: return
	var sty := counter_panel.get_theme_stylebox("panel", "") as StyleBoxFlat
	if sty == null: return
	var active_colors := { "4k-a": Color(1.0, 1.0, 0.3, 1.0), "4k-b": Color(1.0, 1.0, 0.3, 1.0) }
	sty.bg_color = active_colors.get(slot_key, Color(0, 0, 0, 0)) if active else Color(0, 0, 0, 0)
	if active:
		sty.border_color = COLOR_GOLD
		sty.border_width_left = 1; sty.border_width_right = 1
		sty.border_width_top = 1; sty.border_width_bottom = 1
	else:
		sty.border_color = Color(0, 0, 0, 0)
		sty.border_width_left = 0; sty.border_width_right = 0
		sty.border_width_top = 0; sty.border_width_bottom = 0

func _refresh_bonus_stage() -> void:
	if bonus_stage_panel == null or bonus_stage_card == null:
		return
	var bonus: Dictionary = _bonus_presentation()
	var active := bool(bonus.get("active", false))
	if not active:
		var fallback := _fallback_bonus_presentation()
		if bool(fallback.get("active", false)):
			bonus = fallback
			active = true

	var kind := str(bonus.get("kind", "free_games"))
	var amount := store._to_int(bonus.get("amount", 0))
	var free_count := store._to_int(bonus.get("free_game_count", 0))
	var message := str(bonus.get("message", "FREE GAMES BONUS"))
	var card_code := _bonus_presentation_card_code(bonus)
	if card_code.is_empty() and kind == "lucky5":
		card_code = "5S"

	if bonus_message_label != null:
		bonus_message_label.text = message if active else "4 OF A KIND   WINS BONUS"
		bonus_message_label.add_theme_color_override("font_color", COLOR_GOLD if active else COLOR_WHITE)

	match kind:
		"lucky5":
			bonus_stage_label.text = "LUCKY 5"
		"bonus_card":
			bonus_stage_label.text = "BONUS CARD"
		_:
			bonus_stage_label.text = "FREE GAMES"

	if active and amount > 0:
		bonus_stage_amount_label.text = "+%s" % _format_amount(amount)
	elif free_count > 0:
		bonus_stage_amount_label.text = "FREE %d" % free_count
	else:
		bonus_stage_amount_label.text = "BONUS 0"

	_set_bonus_stage_texture(card_code, active)
	_style_bonus_stage(active)
	var next_key := "%s:%s:%s:%s" % [kind, card_code, str(active), str(amount)]
	if next_key != bonus_stage_key:
		bonus_stage_key = next_key
		_animate_bonus_stage(active)

func _bonus_presentation() -> Dictionary:
	var presentation: Dictionary = store.snapshot.get("presentation", {})
	var bonus: Variant = presentation.get("bonus", {})
	if typeof(bonus) == TYPE_DICTIONARY:
		return bonus
	return {}

func _bonus_presentation_card_code(bonus: Dictionary) -> String:
	var card: Variant = bonus.get("card", {})
	if typeof(card) == TYPE_DICTIONARY:
		return str(card.get("code", ""))
	return str(bonus.get("card_code", ""))

func _fallback_bonus_presentation() -> Dictionary:
	var du: Dictionary = store.snapshot.get("double_up", {})
	if store.game_state() == "double_up" and bool(du.get("is_lucky5_active", false)):
		return {
			"active": true,
			"kind": "lucky5",
			"card_code": "5S",
			"amount": du.get("current_amount", 0),
			"free_game_count": 0,
			"message": "5 NEVER LOSE"
		}
	if store.hand_rank() == "FourOfAKind":
		return {
			"active": true,
			"kind": "bonus_card",
			"card_code": _four_kind_rank_card_code(),
			"amount": store.pending_win_amount(),
			"free_game_count": 0,
			"message": "4 OF A KIND BONUS"
		}
	return {
		"active": false,
		"kind": "free_games",
		"card_code": "",
		"amount": 0,
		"free_game_count": 0,
		"message": "FREE GAMES BONUS"
	}

func _four_kind_rank_card_code() -> String:
	var counts := {}
	var first_code_by_rank := {}
	for card_value in store.result_cards():
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = card_value
		var code := str(card.get("code", ""))
		if code.length() < 2:
			continue
		var rank := code.substr(0, code.length() - 1)
		counts[rank] = int(counts.get(rank, 0)) + 1
		if not first_code_by_rank.has(rank):
			first_code_by_rank[rank] = code
	for rank in counts.keys():
		if int(counts[rank]) >= 4:
			return str(first_code_by_rank.get(rank, ""))
	return ""

func _set_bonus_stage_texture(card_code: String, active: bool) -> void:
	var texture: Texture2D = null
	if card_code.length() >= 2:
		texture = _card_texture_from_code(card_code)
	bonus_stage_card.texture = texture if texture != null else _card_back_texture(false)
	bonus_stage_card.modulate = Color(1, 1, 1, 1) if active and texture != null else Color(1, 1, 1, 0.42)

func _style_bonus_stage(active: bool) -> void:
	var sty := bonus_stage_panel.get_theme_stylebox("panel", "") as StyleBoxFlat
	if sty == null:
		return
	if active:
		sty.bg_color = Color(0.235, 0.158, 0.018, 0.95)
		sty.border_color = COLOR_GOLD
		sty.border_width_left = 2; sty.border_width_right = 2
		sty.border_width_top = 2; sty.border_width_bottom = 2
	else:
		sty.bg_color = Color(0.02, 0.01, 0.0, 0.72)
		sty.border_color = COLOR_GOLD_DARK
		sty.border_width_left = 1; sty.border_width_right = 1
		sty.border_width_top = 1; sty.border_width_bottom = 1

func _animate_bonus_stage(active: bool) -> void:
	if bonus_stage_tween != null and bonus_stage_tween.is_valid():
		bonus_stage_tween.kill()
	bonus_stage_panel.pivot_offset = bonus_stage_panel.size * 0.5
	bonus_stage_card.pivot_offset = bonus_stage_card.custom_minimum_size * 0.5
	bonus_stage_panel.scale = Vector2(1.04, 1.04) if active else Vector2(1.0, 1.0)
	bonus_stage_tween = create_tween()
	bonus_stage_tween.set_parallel(true)
	bonus_stage_tween.tween_property(bonus_stage_panel, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if active:
		bonus_stage_card.scale = Vector2(1.16, 1.16)
		bonus_stage_tween.tween_property(bonus_stage_card, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _full_house_rank_text() -> String:
	var jp: Dictionary = store.snapshot.get("jackpot", {})
	var rank: Variant = jp.get("full_house_rank", 0)
	var rank_value: int = store._to_int(rank)
	if rank_value <= 0: return "FH RANK"
	match rank_value:
		14: return "FH RANK: A"
		13: return "FH RANK: K"
		12: return "FH RANK: Q"
		11: return "FH RANK: J"
		10: return "FH RANK: 10"
		9: return "FH RANK: 9"
		8: return "FH RANK: 8"
		7: return "FH RANK: 7"
		6: return "FH RANK: 6"
		5: return "FH RANK: 5"
		_: return "FH RANK: %d" % rank_value

func _full_house_rank_card_code() -> String:
	var jp: Dictionary = store.snapshot.get("jackpot", {})
	var rank: Variant = jp.get("full_house_rank", 0)
	var rank_value: int = store._to_int(rank)
	match rank_value:
		14: return "AS"
		13: return "KS"
		12: return "QS"
		11: return "JS"
		10: return "10S"
		_: return str(max(2, rank_value)) + "S" if rank_value > 0 else "AS"

func _refresh_paytable_values() -> void:
	if full_house_jackpot_label == null or full_house_rank_label == null: return
	var stake: int = max(0, store.stake())
	for key in paytable_amount_labels.keys():
		var amount_l: Label = paytable_amount_labels.get(key, null)
		if amount_l == null: continue
		var multiplier: int = int(paytable_multipliers.get(key, 0))
		amount_l.text = _format_amount(stake * multiplier)
	var jp: Dictionary = store.snapshot.get("jackpot", {})
	full_house_jackpot_label.text = _format_amount(jp.get("full_house", 0))
	full_house_rank_label.text = _full_house_rank_text()

func _refresh_paytable_highlights() -> void:
	var hand_rank: String = store.hand_rank()
	for key in paytable_rows.keys():
		var row_panel: PanelContainer = paytable_rows.get(key, null)
		if row_panel == null: continue
		var sty := row_panel.get_theme_stylebox("panel", "") as StyleBoxFlat
		if sty == null: continue
		var highlighted: bool = str(key) == hand_rank
		sty.bg_color = Color(1.0, 1.0, 0.3, 0.25) if highlighted else Color(0, 0, 0, 0)

func _refresh_machine_info() -> void:
	var machine: Dictionary = store.snapshot.get("machine", {})
	machine_serie_label.text = "SERIE %s" % str(machine.get("machine_serie", "0"))
	machine_kent_label.text = "KENT /3 : %s" % str(machine.get("machine_kent", "0"))
	machine_serial_label.text = "S/N: %s" % str(machine.get("machine_serial", "0"))
	if bonus_message_label != null:
		bonus_message_label.visible = true

func _refresh_credit_display() -> void:
	if credit_label == null:
		return
	var machine_credits := store.machine_credits()
	credit_label.text = store.credit_line()
	if last_machine_credit_amount >= 0 and machine_credits > last_machine_credit_amount:
		_pulse_credit_display()
	last_machine_credit_amount = machine_credits

func _pulse_credit_display() -> void:
	if credit_label == null:
		return
	if credit_pulse_tween != null and credit_pulse_tween.is_valid():
		credit_pulse_tween.kill()
	credit_label.pivot_offset = credit_label.size * 0.5
	credit_label.scale = Vector2(1.05, 1.05)
	credit_pulse_tween = create_tween()
	credit_pulse_tween.tween_property(credit_label, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _refresh_win_display() -> void:
	var pending := store.pending_win_amount()
	var eval: Dictionary = store.snapshot.get("evaluation", {})
	if pending > 0:
		win_slot_label.text = str(eval.get("hand_rank", "WIN"))
		if pending != win_target_amount:
			_animate_win_amount_to(pending)
		elif win_amount_label.text.is_empty():
			_set_win_display_amount(float(pending))
	else:
		if win_target_amount > 0 or win_displayed_amount > 0:
			_animate_win_amount_to(0)
		else:
			win_slot_label.text = ""
			win_amount_label.text = ""

func _animate_win_amount_to(target_amount: int) -> void:
	if win_amount_label == null:
		return
	if win_counter_tween != null and win_counter_tween.is_valid():
		win_counter_tween.kill()
	win_target_amount = max(0, target_amount)
	var distance: int = abs(win_target_amount - win_displayed_amount)
	var duration: float = clampf(float(distance) / 12000000.0, WIN_COUNTER_MIN_DURATION, WIN_COUNTER_MAX_DURATION)
	win_counter_tween = create_tween()
	win_counter_tween.tween_method(Callable(self, "_set_win_display_amount"), float(win_displayed_amount), float(win_target_amount), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	win_counter_tween.finished.connect(_on_win_counter_finished)
	_pulse_win_display()

func _set_win_display_amount(value: Variant) -> void:
	win_displayed_amount = max(0, int(round(float(value))))
	if win_amount_label == null:
		return
	if win_displayed_amount > 0:
		win_amount_label.text = "+%s" % _format_amount(win_displayed_amount)
	else:
		win_amount_label.text = ""

func _pulse_win_display() -> void:
	if win_amount_label == null:
		return
	if win_pulse_tween != null and win_pulse_tween.is_valid():
		win_pulse_tween.kill()
	win_amount_label.pivot_offset = win_amount_label.size * 0.5
	win_amount_label.scale = Vector2(1.10, 1.10)
	win_pulse_tween = create_tween()
	win_pulse_tween.tween_property(win_amount_label, "scale", Vector2(1.0, 1.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_win_counter_finished() -> void:
	if win_target_amount <= 0 and win_displayed_amount <= 0:
		win_slot_label.text = ""
		win_amount_label.text = ""
		win_amount_label.scale = Vector2(1.0, 1.0)

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
	if id == "bet" and store.game_state() == "double_up" and store.can_press("double_up_switch"): return true
	if id == "take_score" and store.can_press("cash_out"): return true
	return store.can_press(id)

func _refresh_admin_users() -> void:
	for c in admin_users_list.get_children(): c.queue_free()
	if admin_search_results.is_empty():
		admin_users_list.add_child(_make_label("No users found", 12, COLOR_GREY, HORIZONTAL_ALIGNMENT_CENTER)); return
	for user in admin_search_results:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var ud: Dictionary = user if typeof(user) == TYPE_DICTIONARY else {}
		var name_l := _make_label(str(ud.get("username", "?")), 12, COLOR_CREAM)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(_make_label(_format_amount(ud.get("walletBalance", "0")), 12, COLOR_GREEN, HORIZONTAL_ALIGNMENT_RIGHT))
		row.add_child(_make_label(str(ud.get("role", "")), 12, COLOR_BLUE, HORIZONTAL_ALIGNMENT_RIGHT))
		var assign_button := _make_button("ASSIGN", 30, COLOR_PANEL_BG.lightened(0.2), COLOR_GOLD, COLOR_GOLD_DARK)
		assign_button.disabled = admin_selected_agent_id <= 0
		assign_button.pressed.connect(_on_admin_assign_user.bind(str(ud.get("userId", ""))))
		row.add_child(assign_button)
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

func _refresh_admin_agents() -> void:
	for c in admin_agents_list.get_children(): c.queue_free()
	if admin_agent_list.is_empty():
		admin_agents_list.add_child(_make_label("No agents found", 12, COLOR_GREY, HORIZONTAL_ALIGNMENT_CENTER)); return
	for agent in admin_agent_list:
		var ad: Dictionary = agent if typeof(agent) == TYPE_DICTIONARY else {}
		var agent_id := int(ad.get("id", 0))
		var selected := agent_id == admin_selected_agent_id
		var label := "%s  %s  %s" % [str(ad.get("code", "?")), str(ad.get("name", "?")), _format_amount(ad.get("creditPool", 0))]
		var row_button := _make_button(("> " if selected else "") + label, 32, COLOR_PANEL_BG.lightened(0.24 if selected else 0.12), COLOR_CREAM, COLOR_GOLD_DARK)
		row_button.pressed.connect(_on_admin_select_agent.bind(agent_id))
		admin_agents_list.add_child(row_button)

func _show_admin_section(section: String) -> void:
	if admin_agent_tools != null: admin_agent_tools.visible = section == "agents"
	if admin_agents_list != null: admin_agents_list.visible = section == "agents"
	if admin_user_search_row != null: admin_user_search_row.visible = section == "users"
	if admin_users_list != null: admin_users_list.visible = section == "users"
	if admin_machines_list != null: admin_machines_list.visible = section == "machines"

# ─── input handlers ───
func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_hold(index)

func _on_hold_button_pressed(index: int) -> void:
	_toggle_hold(index)

func _toggle_hold(index: int) -> void:
	if _has_pending_command(): return
	if not store.can_press("hold_%d" % index): return
	if local_hold_indexes.is_empty():
		local_hold_indexes = _editable_hold_baseline()
	if local_hold_indexes.has(index): local_hold_indexes.erase(index)
	else: local_hold_indexes.append(index); local_hold_indexes.sort()
	auto_holds_cancelled = local_hold_indexes.is_empty()
	_refresh_ui()

func _on_menu_close_pressed() -> void:
	menu_open = false
	_refresh_ui()

func _on_action_pressed(id: String) -> void:
	match id:
		"menu":
			menu_open = not menu_open
			_refresh_ui()
		"cash_in":
			cash_in_amount = _sanitize_cash_amount(cash_in_edit.text); cash_in_edit.text = str(cash_in_amount)
			_send_command("cash_in", {"amount": str(cash_in_amount)})
		"cash_out": _send_command("cash_out", {})
		"deal_draw":
			if store.game_state() == "hold":
				var round_id := store.current_round_id()
				if not round_id.is_empty(): _send_command("draw", {"round_id": round_id, "hold_indexes": _draw_hold_indexes()})
			else: _send_command("deal", {"bet_amount": str(selected_bet)})
		"bet":
			if store.game_state() == "double_up" and store.can_press("double_up_switch"):
				var switch_round_id := store.current_round_id()
				if not switch_round_id.is_empty(): _send_command("double_up_switch", {"round_id": switch_round_id})
			else: _cycle_bet()
		"cancel_hold": local_hold_indexes.clear(); auto_holds_cancelled = true; _send_command("clear_holds", {}); _refresh_ui()
		"big": _send_double_up_guess("big")
		"small": _send_double_up_guess("small")
		"swap_double_up_card":
			var switch_round_id := store.current_round_id()
			if not switch_round_id.is_empty(): _send_command("double_up_switch", {"round_id": switch_round_id})
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
		"admin_toggle":
			var opening := active_screen != "admin"
			active_screen = "admin" if opening else "game"
			menu_open = false
			if opening:
				_show_admin_section("agents")
				if not access_token.is_empty(): api.get_admin_agents()
			_refresh_ui()
		"admin_agents": _on_admin_agents()
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

func _on_admin_agents() -> void:
	_show_admin_section("agents")
	if not access_token.is_empty(): api.get_admin_agents()

func _on_admin_machines() -> void:
	_show_admin_section("machines")
	if not access_token.is_empty(): api.get_admin_machines()

func _on_admin_users() -> void:
	_show_admin_section("users")
	if not access_token.is_empty(): api.get_admin_users()

func _on_admin_search() -> void:
	_show_admin_section("users")
	var q := admin_search_edit.text.strip_edges()
	if q.is_empty():
		if not access_token.is_empty(): api.get_admin_users()
	else:
		if not access_token.is_empty(): api.search_admin_users(q)

func _on_admin_select_agent(agent_id: int) -> void:
	if agent_id <= 0: return
	admin_selected_agent_id = agent_id
	_refresh_admin_agents()
	_refresh_admin_users()

func _on_admin_create_agent() -> void:
	var name := admin_agent_name_edit.text.strip_edges()
	var code := admin_agent_code_edit.text.strip_edges().to_upper()
	var phone := admin_agent_phone_edit.text.strip_edges()
	if name.is_empty() or code.is_empty():
		recovery_label.text = "Admin agent needs name and code."; return
	if phone.is_empty(): phone = "N/A"
	if not access_token.is_empty() and api.create_admin_agent(name, code, phone):
		admin_agent_name_edit.text = ""
		admin_agent_code_edit.text = ""
		admin_agent_phone_edit.text = ""

func _on_admin_load_agent_credit() -> void:
	if admin_selected_agent_id <= 0:
		recovery_label.text = "Select an agent before loading credit."; return
	var amount_text := admin_agent_credit_edit.text.strip_edges()
	var amount := int(float(amount_text)) if amount_text.is_valid_float() else 0
	if amount <= 0:
		recovery_label.text = "Enter a positive agent credit amount."; return
	if not access_token.is_empty(): api.load_admin_agent_credit(admin_selected_agent_id, amount)

func _on_admin_assign_user(user_id: String) -> void:
	if admin_selected_agent_id <= 0:
		recovery_label.text = "Select an agent before assigning a user."; return
	if user_id.strip_edges().is_empty(): return
	if not access_token.is_empty(): api.assign_admin_user_to_agent(admin_selected_agent_id, user_id.strip_edges())

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

func _process_deal_queue() -> void:
	if deal_queue_index >= deal_queue.size():
		deal_queue.clear()
		deal_queue_index = 0
		return

	var reveal: Dictionary = deal_queue[deal_queue_index]
	deal_queue_index += 1
	_show_queued_card(reveal)

	if deal_queue_index < deal_queue.size():
		deal_timer.wait_time = DRAW_STAGGER if str(reveal.get("mode", "deal")) == "draw" else DEAL_STAGGER
		deal_timer.start()
	else:
		deal_queue.clear()
		deal_queue_index = 0
		deal_timer.wait_time = DEAL_STAGGER
