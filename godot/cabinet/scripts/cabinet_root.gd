extends Control
class_name CabinetRoot

const CabinetApiScript = preload("res://scripts/cabinet_api.gd")
const CabinetStoreScript = preload("res://scripts/cabinet_store.gd")
const CARD_FLIP_SHADER_PATH := "res://shaders/card_flip.gdshader"
const CRT_SHADER_PATH := "res://shaders/crt_effect.gdshader"

enum ConnectionState {
	OFFLINE,
	CONNECTING,
	SYNCING_SNAPSHOT,
	LIVE,
	RECONNECTING,
	RECOVERY_REQUIRED
}

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
const BUTTON_ASSET_BASE_PATH := "res://skins/cabinet_ai9/buttons/"
const CABINET_AI9_SKIN_ROOT := "res://skins/cabinet_ai9/"
const CABINET_BOARD_TEXTURE := "images/board.png"
const CABINET_PRESS_SOUND := "audio/press.mp3"
const CABINET_DEAL_WHOOSH := "audio/deal_whoosh.mp3"
const CABINET_SHUFFLE_TICK := "audio/shuffle_tick.mp3"
const CABINET_CREDIT_TRICKLE := "audio/credit_trickle.mp3"
const BUTTON_ASSET_FONT_SIZE := 13

const CARD_AREA_MIN_HEIGHT := 300
# AI9 fronts are 313x528; keep slot boxes on that portrait ratio so cards stay crisp.
const AI9_CARD_ASPECT := 313.0 / 528.0
const CARD_SIZE := Vector2(150, 254)
const CARD_SMALL_SIZE := Vector2(70, 118)
const CARD_GAP := 8
const CONTROL_DECK_MIN_HEIGHT := 340
const CONTROL_HOLD_BUTTON_HEIGHT := 76
const CONTROL_ACTION_BUTTON_HEIGHT := 86
const CONTROL_BOTTOM_BUTTON_HEIGHT := 78
const DEAL_DURATION := 0.12
const DEAL_STAGGER := 0.10
const DRAW_OUT_DURATION := 0.08
const DRAW_IN_DURATION := 0.12
const DRAW_STAGGER := 0.10
const DU_SWITCH_DURATION := 0.40
const DU_BOARD_CARD_SIZE := Vector2(116, 196)
const DU_TRAIL_CARD_SIZE := Vector2(150, 254)
const BONUS_COIN_SIZE := Vector2(32, 32)
const DOUBLE_UP_BOARD_SLOT_COUNT := 5
const DU_SHUFFLE_INTERVAL := 0.08
const DU_SHUFFLE_TICKS := 4
const DU_SHUFFLE_CODES := ["AS", "KH", "QD", "JC", "10S", "9H", "8D", "7C"]
const DU_REVEAL_SETTLE_SECONDS := 0.50
const DU_END_HOLD_SECONDS := 0.50
const DOUBLE_UP_AUTO_ENTRY_DELAY_SECONDS := 1.00
const IDLE_FH_CARD_DELAY_SECONDS := 60.0
const IDLE_TITLE_TEXT := "LUCKY 5\nPOKER"
const WIN_COUNTER_MIN_DURATION := 0.18
const WIN_COUNTER_MAX_DURATION := 0.75
const CREDIT_DRAIN_MIN_DURATION := 1.20
const CREDIT_DRAIN_MAX_DURATION := 2.00
const CREDIT_DRAIN_JACKPOT_DURATION := 5.00
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
var last_game_state := ""
var authenticating := false
var pending_signup_username := ""
var pending_signup_password := ""
var auth_status := "LOGIN REQUIRED - SIGN IN TO PLAY"
var cards_texture_rects: Array = []
var du_cards: Array = []
var active_screen := "game"
var connection_state := ConnectionState.OFFLINE
var last_heartbeat_response_time := 0.0
var connection_state_label: Label
var recovery_overlay: PanelContainer
var recovery_overlay_label: Label
var diagnostics_panel: VBoxContainer
var diag_fps_label: Label
var diag_memory_label: Label
var diag_ping_label: Label
var diag_heartbeat_label: Label
var diag_machine_id_label: Label
var diag_session_id_label: Label
var diag_state_version_label: Label
var diag_sequence_label: Label
var diag_hand_rank_label: Label
var diag_payout_label: Label
var diag_du_trail_label: Label
var diag_visible := false
var diag_fps_accum := 0.0
var diag_fps_counter := 0
var admin_search_results: Array = []
var admin_machine_list: Array = []
var admin_agent_list: Array = []
var admin_selected_agent_id := 0
var pending_command_id := ""
var pending_idempotency_key := ""
var pending_command_type := ""
var button_asset_textures: Dictionary = {}
var button_asset_styleboxes: Array = []
var cabinet_texture_cache: Dictionary = {}
var cabinet_audio_cache: Dictionary = {}
var arcade_font: Font
var impact_font: Font
var ui_font: Font
var press_sound: AudioStream
var press_audio_player: AudioStreamPlayer
var deal_whoosh_sound: AudioStream
var deal_whoosh_player: AudioStreamPlayer
var shuffle_tick_sound: AudioStream
var shuffle_tick_player: AudioStreamPlayer
var credit_trickle_sound: AudioStream
var credit_trickle_player: AudioStreamPlayer
var card_flip_shader: Shader
var card_flip_material: ShaderMaterial
var crt_shader: Shader
var crt_shader_material: ShaderMaterial
var crt_time := 0.0

# ─── node refs ───
var title_label: Label
var paytable_rows: Dictionary = {}
var paytable_amount_labels: Dictionary = {}
var paytable_multipliers: Dictionary = {}
var paytable_amount_colors: Dictionary = {}
var full_house_rank_label: Label
var full_house_jackpot_label: Label
var credit_label: Label
var credit_value_label: Label
var stake_value_label: Label
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
var menu_balance_label: Label
var menu_open := false
var card_area_panel: Panel
var card_center: CenterContainer
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
var du_end_hold_timer: Timer
var auto_double_up_timer: Timer
var idle_fh_timer: Timer
var idle_fh_rank_revealed := false
var deal_queue: Array = []
var deal_queue_index := 0
var du_anim_queue: Array = []
var du_shuffle_ticks_remaining := 0
var du_shuffle_index := 0
var du_shuffle_target_dealer := ""
var du_shuffle_target_challenger := ""
var du_shuffle_replace_dealer_only := false
var du_pending_promote_dealer := ""
var du_pending_promote_trail_code := ""
var du_pending_promote_trail_label := ""
var du_local_trail_entries: Array = []
var du_last_active_data: Dictionary = {}
var du_end_hold_data: Dictionary = {}
var du_end_hold_active := false
var du_was_active := false
var auto_double_up_round_ids: Array = []
var auto_double_up_pending_round_id := ""
var _prev_dealer_code := ""
var _prev_challenger_code := ""
var _prev_switches_remaining := -1
var du_last_switch_dealer_code := ""
var win_displayed_amount := 0
var win_target_amount := 0
var win_paytable_rank_key := ""
var win_counter_tween: Tween
var win_pulse_tween: Tween
var credit_pulse_tween: Tween
var credit_counter_tween: Tween
var last_machine_credit_amount := -1
var displayed_machine_credit_amount := -1
var credit_target_amount := -1
var credit_transfer_active := false
var displayed_jackpots: Dictionary = {}
var jackpot_counter_targets: Dictionary = {}
var jackpot_counter_tweens: Dictionary = {}

# ─── lifecycle ───
func _ready() -> void:
	_load_environment()
	_load_cabinet_skin_resources()
	_load_shaders()
	_build_ui()
	_create_press_audio_player()
	_load_fixture_snapshot()

	api = CabinetApiScript.new()
	add_child(api)
	api.configure(api_base_url, access_token)
	api.request_completed.connect(_on_api_response)

	heartbeat_timer = Timer.new(); heartbeat_timer.wait_time = 15.0; heartbeat_timer.autostart = true
	heartbeat_timer.timeout.connect(_send_heartbeat); add_child(heartbeat_timer)
	_enter_connection_state(ConnectionState.OFFLINE)

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

	du_end_hold_timer = Timer.new(); du_end_hold_timer.wait_time = DU_END_HOLD_SECONDS; du_end_hold_timer.one_shot = true
	du_end_hold_timer.timeout.connect(_on_du_end_hold_timeout); add_child(du_end_hold_timer)

	auto_double_up_timer = Timer.new(); auto_double_up_timer.wait_time = DOUBLE_UP_AUTO_ENTRY_DELAY_SECONDS; auto_double_up_timer.one_shot = true
	auto_double_up_timer.timeout.connect(_on_auto_double_up_timer_timeout); add_child(auto_double_up_timer)

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

func _exit_tree() -> void:
	_release_cabinet_resource_refs(self)
	_release_button_asset_styles(self)
	for style in button_asset_styleboxes:
		if style is StyleBoxTexture:
			(style as StyleBoxTexture).texture = null
	button_asset_styleboxes.clear()
	button_asset_textures.clear()
	cabinet_texture_cache.clear()
	cabinet_audio_cache.clear()
	arcade_font = null
	impact_font = null
	ui_font = null
	press_sound = null
	press_audio_player = null
	_stop_timers_for_exit()

func _release_cabinet_resource_refs(node: Node) -> void:
	if node is Label:
		(node as Label).remove_theme_font_override("font")
	elif node is TextureRect:
		(node as TextureRect).texture = null
	elif node is AudioStreamPlayer:
		var audio_player := node as AudioStreamPlayer
		audio_player.stop()
		audio_player.stream = null
	for child in node.get_children():
		_release_cabinet_resource_refs(child)

func _release_button_asset_styles(node: Node) -> void:
	if node is Button:
		var button := node as Button
		if _button_uses_asset(button):
			for state in ["normal", "hover", "pressed", "disabled"]:
				var style := button.get_theme_stylebox(state, "") as StyleBoxTexture
				if style != null:
					style.texture = null
				button.remove_theme_stylebox_override(state)
	for child in node.get_children():
		_release_button_asset_styles(child)

func _stop_timers_for_exit() -> void:
	for timer in [heartbeat_timer, replay_timer, token_refresh_timer, command_timeout_timer, deal_timer, du_shuffle_timer, du_promote_timer, du_end_hold_timer, auto_double_up_timer, idle_fh_timer]:
		if timer != null:
			timer.stop()

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

func _load_cabinet_skin_resources() -> void:
	if DisplayServer.get_name() != "headless":
		arcade_font = _load_cabinet_font("fonts/ARCADE.ttf")
		impact_font = _load_cabinet_font("fonts/Impact.ttf")
		ui_font = _load_cabinet_font("fonts/InterSemiBold.ttf")
	press_sound = _load_cabinet_audio(CABINET_PRESS_SOUND)
	deal_whoosh_sound = _load_cabinet_audio(CABINET_DEAL_WHOOSH)
	shuffle_tick_sound = _load_cabinet_audio(CABINET_SHUFFLE_TICK)
	credit_trickle_sound = _load_cabinet_audio(CABINET_CREDIT_TRICKLE)

func _cabinet_resource_path(relative_path: String) -> String:
	var path := CABINET_AI9_SKIN_ROOT + relative_path
	if ResourceLoader.exists(path):
		return path
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		return path
	return ""

func _load_cabinet_texture(relative_path: String) -> Texture2D:
	if cabinet_texture_cache.has(relative_path):
		return cabinet_texture_cache[relative_path] as Texture2D
	var path := _cabinet_resource_path(relative_path)
	if path.is_empty():
		return null
	var texture := ResourceLoader.load(path) as Texture2D
	if texture != null:
		cabinet_texture_cache[relative_path] = texture
	return texture

func _load_cabinet_audio(relative_path: String) -> AudioStream:
	if cabinet_audio_cache.has(relative_path):
		return cabinet_audio_cache[relative_path] as AudioStream
	var path := _cabinet_resource_path(relative_path)
	if path.is_empty():
		return null
	var audio := ResourceLoader.load(path) as AudioStream
	if audio != null:
		cabinet_audio_cache[relative_path] = audio
	return audio

func _load_cabinet_font(relative_path: String) -> Font:
	var path := _cabinet_resource_path(relative_path)
	if path.is_empty():
		return null
	return ResourceLoader.load(path) as Font

func _load_shaders() -> void:
	if ResourceLoader.exists(CARD_FLIP_SHADER_PATH):
		card_flip_shader = ResourceLoader.load(CARD_FLIP_SHADER_PATH) as Shader
		if card_flip_shader != null:
			card_flip_material = ShaderMaterial.new()
			card_flip_material.shader = card_flip_shader
			card_flip_material.set_shader_parameter("flip_progress", 0.0)
			card_flip_material.set_shader_parameter("edge_color", Color(0.0, 0.0, 0.0, 0.0))
			card_flip_material.set_shader_parameter("shadow_intensity", 0.42)
	if ResourceLoader.exists(CRT_SHADER_PATH):
		crt_shader = ResourceLoader.load(CRT_SHADER_PATH) as Shader
		if crt_shader != null:
			crt_shader_material = ShaderMaterial.new()
			crt_shader_material.shader = crt_shader
			crt_shader_material.set_shader_parameter("time", 0.0)
			crt_shader_material.set_shader_parameter("curvature", 0.04)
			crt_shader_material.set_shader_parameter("scanline_opacity", 0.10)
			crt_shader_material.set_shader_parameter("vignette_strength", 0.45)
			crt_shader_material.set_shader_parameter("phosphor_bloom", 0.03)
			crt_shader_material.set_shader_parameter("viewport_size", Vector2(720, 1280))

func _process(delta: float) -> void:
	if crt_shader_material != null:
		crt_time += delta
		crt_shader_material.set_shader_parameter("time", crt_time)
	if diag_visible:
		diag_fps_accum += delta
		diag_fps_counter += 1
		if diag_fps_accum >= 1.0:
			_refresh_diagnostics()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			diag_visible = not diag_visible
			if diagnostics_panel != null:
				diagnostics_panel.visible = diag_visible
			if diag_visible:
				diag_fps_accum = 0.0
				diag_fps_counter = 0
				_refresh_diagnostics()
			get_viewport().set_input_as_handled()

func _create_press_audio_player() -> void:
	if press_sound != null:
		press_audio_player = _create_audio_player("CabinetPressAudio", press_sound, -4.0)
	if deal_whoosh_sound != null:
		deal_whoosh_player = _create_audio_player("CabinetDealWhoosh", deal_whoosh_sound, -6.0)
	if shuffle_tick_sound != null:
		shuffle_tick_player = _create_audio_player("CabinetShuffleTick", shuffle_tick_sound, -8.0)
	if credit_trickle_sound != null:
		credit_trickle_player = _create_audio_player("CabinetCreditTrickle", credit_trickle_sound, -10.0)

func _create_audio_player(p_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = p_name
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player

func _play_press_sound() -> void:
	if press_audio_player == null:
		return
	press_audio_player.stop()
	press_audio_player.play()

func _play_deal_whoosh() -> void:
	if deal_whoosh_player == null:
		return
	deal_whoosh_player.stop()
	deal_whoosh_player.play()

func _play_shuffle_tick() -> void:
	if shuffle_tick_player == null:
		return
	shuffle_tick_player.stop()
	shuffle_tick_player.play()

func _play_credit_trickle() -> void:
	if credit_trickle_player == null:
		return
	credit_trickle_player.stop()
	credit_trickle_player.play()

func _font_for_key(font_key: String) -> Font:
	match font_key:
		"impact":
			return impact_font if impact_font != null else arcade_font
		"ui":
			return ui_font if ui_font != null else arcade_font
		_:
			return arcade_font if arcade_font != null else ui_font

# ─── helper: create styled label ───
func _make_label(text_str: String, size: int, color_val: Color, align := HORIZONTAL_ALIGNMENT_LEFT, font_key := "arcade") -> Label:
	var l := Label.new()
	l.text = text_str
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color_val)
	var label_font := _font_for_key(font_key)
	if label_font != null:
		l.add_theme_font_override("font", label_font)
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
	button_asset_styleboxes.append(style)
	return style

func _load_button_asset_texture(asset_name: String) -> Texture2D:
	if button_asset_textures.has(asset_name):
		return button_asset_textures[asset_name] as Texture2D
	var path := BUTTON_ASSET_BASE_PATH + asset_name + ".png"
	if not ResourceLoader.exists(path):
		return null
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		return null
	button_asset_textures[asset_name] = texture
	return texture

func _button_asset_normal_name(asset_key: String) -> String:
	if asset_key == "hold":
		return "hold_off"
	return asset_key

func _button_asset_active_name(asset_key: String) -> String:
	if asset_key == "hold":
		return "hold_on"
	var active_name := "%s_on" % asset_key
	var active_path := BUTTON_ASSET_BASE_PATH + active_name + ".png"
	return active_name if ResourceLoader.exists(active_path) else _button_asset_normal_name(asset_key)

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

	_add_cabinet_board_background(self, 0.56)

	crt_overlay = ColorRect.new()
	crt_overlay.color = Color(0, 0, 0, 0.06)
	crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if crt_shader_material != null:
		crt_overlay.material = crt_shader_material
		crt_overlay.color = Color.WHITE
	add_child(crt_overlay)
	_create_scanlines()
	_build_recovery_overlay(self)

	var root := ScrollContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)

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
	bottom_spacer.custom_minimum_size = Vector2(0, 4)
	content.add_child(bottom_spacer)

	_build_control_deck(content)
	_build_menu_panel(self)

	_build_admin_screen(content)

func _add_cabinet_board_background(parent: Control, alpha: float) -> TextureRect:
	var texture := _load_cabinet_texture(CABINET_BOARD_TEXTURE)
	if texture == null:
		return null
	var board := TextureRect.new()
	board.name = "CabinetAi9BoardTexture"
	board.texture = texture
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.modulate = Color(1, 0.82, 0.56, alpha)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(board)
	return board

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
	deck.clip_contents = true
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
	_add_cabinet_board_background(deck, 0.72)
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

	menu_balance_label = _make_label("", 11, COLOR_GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	menu_balance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_panel.add_child(menu_balance_label)

	_build_auth_panel(menu_panel)

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
	if crt_shader_material != null:
		return
	var sl := ColorRect.new()
	sl.color = Color(0, 0, 0, 0.06)
	sl.set_anchors_preset(Control.PRESET_FULL_RECT)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sl)

func _build_recovery_overlay(parent: Node) -> void:
	recovery_overlay = PanelContainer.new()
	recovery_overlay.name = "RecoveryOverlay"
	recovery_overlay.visible = false
	recovery_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.82)
	recovery_overlay.add_theme_stylebox_override("panel", overlay_style)
	parent.add_child(recovery_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	recovery_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	recovery_overlay_label = _make_label("RECOVERING CONNECTION...", 28, COLOR_RED, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(recovery_overlay_label)

	var subtitle := _make_label("Please wait while the cabinet reconnects.", 14, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(subtitle)

	connection_state_label = _make_label("", 11, COLOR_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(connection_state_label)

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
	paytable_amount_colors.clear()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 162)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.078, 0.039, 0.016, 0.8)
	ps.border_color = COLOR_GOLD_DARK
	ps.border_width_left = 1; ps.border_width_right = 1
	ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.corner_radius_top_left = 6; ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6; ps.corner_radius_bottom_right = 6
	ps.content_margin_left = 6; ps.content_margin_right = 6
	ps.content_margin_top = 4; ps.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	# ── ai9 layout: paytable column on the left, CREDIT / STAKE column on the right ──
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(columns)

	var pbox := VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 2)
	pbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbox.size_flags_stretch_ratio = 1.7
	columns.add_child(pbox)

	_build_credit_stake_column(columns)

	var hands := [
		["RoyalFlush", "ROYAL FLUSH", 1000, Color(1.0, 0.90, 0.90)],
		["StraightFlush", "STRAIGHT FLUSH", 75, COLOR_RED],
		["FourOfAKind", "FOUR OF A KIND", 15, COLOR_BLUE],
		["FullHouse", "FULL HOUSE", 12, COLOR_GOLD],
		["Flush", "FLUSH", 10, COLOR_RED],
		["Straight", "STRAIGHT", 8, COLOR_GREEN],
		["ThreeOfAKind", "THREE OF A KIND", 3, COLOR_BLUE],
		["TwoPair", "TWO PAIR", 2, COLOR_GOLD],
	]
	for hand in hands:
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 16)
		var rps := StyleBoxFlat.new()
		rps.bg_color = Color(0, 0, 0, 0)
		rps.border_color = Color(0, 0, 0, 0)
		rps.border_width_left = 0; rps.border_width_right = 0
		rps.border_width_top = 0; rps.border_width_bottom = 0
		rps.content_margin_left = 3; rps.content_margin_right = 3
		rps.content_margin_top = 1; rps.content_margin_bottom = 1
		row_panel.add_theme_stylebox_override("panel", rps)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row_panel.add_child(row)
		var name_l := _make_label(hand[1], 13, hand[3])
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		row.add_child(name_l)
		var amount_l := _make_label("0", 13, hand[3], HORIZONTAL_ALIGNMENT_RIGHT)
		amount_l.custom_minimum_size = Vector2(110, 0)
		row.add_child(amount_l)
		paytable_rows[str(hand[0])] = row_panel
		paytable_amount_labels[str(hand[0])] = amount_l
		paytable_multipliers[str(hand[0])] = int(hand[2])
		paytable_amount_colors[str(hand[0])] = hand[3]
		pbox.add_child(row_panel)

	var fh_rank_row := HBoxContainer.new()
	fh_rank_row.add_theme_constant_override("separation", 4)
	pbox.add_child(fh_rank_row)
	full_house_rank_label = _make_label(_full_house_rank_text(), 13, COLOR_GOLD)
	fh_rank_row.add_child(full_house_rank_label)
	full_house_jackpot_label = _make_label("0", 13, COLOR_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	full_house_jackpot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh_rank_row.add_child(full_house_jackpot_label)
	jackpot_counters["fh"] = full_house_jackpot_label

func _build_credit_stake_column(parent: Node) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(column)

	credit_label = _make_label("CREDIT", 13, COLOR_GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	credit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(credit_label)

	credit_value_label = _make_label("0", 20, COLOR_WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	credit_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(credit_value_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	column.add_child(spacer)

	var stake_caption := _make_label("STAKE", 13, COLOR_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	stake_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(stake_caption)

	stake_value_label = _make_label("0", 20, COLOR_WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	stake_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(stake_value_label)

func _build_credit_bar(_parent: Node) -> void:
	# Credit / stake are rendered inside the paytable header column (ai9 layout).
	pass

func _build_card_area(parent: Node) -> void:
	card_area_panel = Panel.new()
	var cps := StyleBoxFlat.new()
	cps.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	cps.border_color = COLOR_GOLD_DARK
	cps.border_width_left = 1; cps.border_width_right = 1
	cps.border_width_top = 1; cps.border_width_bottom = 1
	cps.corner_radius_top_left = 8; cps.corner_radius_top_right = 8
	cps.corner_radius_bottom_left = 8; cps.corner_radius_bottom_right = 8
	card_area_panel.add_theme_stylebox_override("panel", cps)
	card_area_panel.custom_minimum_size = Vector2(0, CARD_AREA_MIN_HEIGHT)
	card_area_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card_area_panel)

	card_center = CenterContainer.new()
	card_center.name = "CardAreaCenter"
	card_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_area_panel.add_child(card_center)

	card_container = HBoxContainer.new()
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	card_container.add_theme_constant_override("separation", CARD_GAP)
	card_center.add_child(card_container)

	idle_title_label = _make_label(IDLE_TITLE_TEXT, 64, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	idle_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	idle_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	idle_title_label.add_theme_color_override("font_color", Color(0.298, 0.792, 1.0))
	idle_title_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.20, 0.36, 0.95))
	idle_title_label.add_theme_constant_override("shadow_offset_x", 0)
	idle_title_label.add_theme_constant_override("shadow_offset_y", 4)
	idle_title_label.add_theme_constant_override("shadow_outline_size", 6)
	idle_title_label.add_theme_constant_override("line_spacing", 8)
	idle_title_label.visible = false
	card_area_panel.add_child(idle_title_label)

	for index in range(5):
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 2)

		var tr := TextureRect.new()
		tr.custom_minimum_size = CARD_SIZE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_STOP
		tr.gui_input.connect(_on_card_gui_input.bind(index))
		if card_flip_material != null:
			var mat := card_flip_material.duplicate() as ShaderMaterial
			mat.set_shader_parameter("flip_progress", 0.0)
			tr.material = mat
		slot.add_child(tr)

		var hold_label := _make_label("", 12, COLOR_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
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

	_build_du_deck_row(card_center)

func _build_win_display(_parent: Node) -> void:
	win_slot_label = _make_label("", 14, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	win_slot_label.visible = false
	win_amount_label = _make_label("", 26, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	win_amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	win_amount_label.add_theme_constant_override("shadow_offset_x", 2)
	win_amount_label.add_theme_constant_override("shadow_offset_y", 2)
	win_amount_label.add_theme_constant_override("shadow_outline_size", 2)
	win_amount_label.visible = false

func _build_machine_info(parent: Node) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 110)
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

	machine_serie_label = _make_label("SERIE 0", 13, COLOR_GREEN)
	hbox.add_child(machine_serie_label)
	machine_kent_label = _make_label("KENT /3 : 0", 13, COLOR_GREEN)
	hbox.add_child(machine_kent_label)
	machine_serial_label = _make_label("S/N: 0", 13, COLOR_GREEN)
	machine_serial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	machine_serial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(machine_serial_label)

	var jp_row := HBoxContainer.new()
	jp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	jp_row.add_theme_constant_override("separation", 10)
	jp_row.custom_minimum_size = Vector2(0, 34)
	rows.add_child(jp_row)

	jackpot_counter_panels.clear()
	for slot in [["*", "4k-a", COLOR_GREEN_DIM], ["SF", "sf", COLOR_GOLD], ["*", "4k-b", COLOR_GREEN_DIM]]:
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
		var val := _make_label("0", 14, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		counter_box.add_child(val)
		jackpot_counters[str(slot[1])] = val
		jackpot_counter_panels[str(slot[1])] = counter_panel
		jp_row.add_child(counter_panel)

	var bonus_row := HBoxContainer.new()
	bonus_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bonus_row.add_theme_constant_override("separation", 6)
	bonus_row.custom_minimum_size = Vector2(0, 40)
	rows.add_child(bonus_row)

	bonus_message_label = _make_label("4 OF A KIND   WINS BONUS", 15, COLOR_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	bonus_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_message_label.custom_minimum_size = Vector2(0, 34)
	bonus_message_label.visible = true
	bonus_row.add_child(bonus_message_label)

	bonus_stage_label = _make_label("FREE GAMES", 13, COLOR_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	bonus_stage_label.custom_minimum_size = Vector2(220, 18)
	bonus_stage_label.visible = false
	bonus_row.add_child(bonus_stage_label)

	bonus_stage_amount_label = _make_label("BONUS 0", 13, COLOR_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	bonus_stage_amount_label.custom_minimum_size = Vector2(180, 18)
	bonus_stage_amount_label.visible = false
	bonus_row.add_child(bonus_stage_amount_label)

func _build_du_info(parent: Node) -> void:
	du_info_panel = VBoxContainer.new()
	du_info_panel.visible = false
	du_info_panel.add_theme_constant_override("separation", 2)
	parent.add_child(du_info_panel)

	du_label_node = _make_label("HI LO GAMBLE", 14, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	du_info_panel.add_child(du_label_node)

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

func _build_du_deck_row(parent: Node) -> void:
	du_trail_container = HBoxContainer.new()
	du_trail_container.name = "DoubleUpDeckRow"
	du_trail_container.visible = false
	du_trail_container.alignment = BoxContainer.ALIGNMENT_CENTER
	du_trail_container.add_theme_constant_override("separation", CARD_GAP)
	parent.add_child(du_trail_container)

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
		slot_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(slot_rect)
		du_trail_container.add_child(slot)
		du_cards.append({ "label": slot_label, "rect": slot_rect })
		if index == 0:
			du_dealer_label = slot_label
			du_dealer_rect = slot_rect
		elif index == 1:
			du_challenger_label = slot_label
			du_challenger_rect = slot_rect

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

	_build_diagnostics_panel(admin_screen)

func _build_diagnostics_panel(parent: Node) -> void:
	diagnostics_panel = VBoxContainer.new()
	diagnostics_panel.name = "DiagnosticsPanel"
	diagnostics_panel.visible = false
	diagnostics_panel.add_theme_constant_override("separation", 2)

	var header := _make_label("DIAGNOSTICS (F2 to toggle)", 14, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	diagnostics_panel.add_child(header)

	var sep := HSeparator.new()
	diagnostics_panel.add_child(sep)

	diag_fps_label = _make_label("FPS: --", 11, COLOR_GREEN)
	diagnostics_panel.add_child(diag_fps_label)
	diag_memory_label = _make_label("MEM: --", 11, COLOR_GREEN)
	diagnostics_panel.add_child(diag_memory_label)
	diag_ping_label = _make_label("PING: -- ms", 11, COLOR_BLUE)
	diagnostics_panel.add_child(diag_ping_label)
	diag_heartbeat_label = _make_label("HB: --", 11, COLOR_CREAM)
	diagnostics_panel.add_child(diag_heartbeat_label)

	var sep2 := HSeparator.new()
	diagnostics_panel.add_child(sep2)

	diag_machine_id_label = _make_label("MACHINE: --", 11, COLOR_WHITE)
	diagnostics_panel.add_child(diag_machine_id_label)
	diag_session_id_label = _make_label("SESSION: --", 11, COLOR_WHITE)
	diagnostics_panel.add_child(diag_session_id_label)
	diag_state_version_label = _make_label("STATE VER: --", 11, COLOR_WHITE)
	diagnostics_panel.add_child(diag_state_version_label)
	diag_sequence_label = _make_label("SEQ: --", 11, COLOR_WHITE)
	diagnostics_panel.add_child(diag_sequence_label)

	var sep3 := HSeparator.new()
	diagnostics_panel.add_child(sep3)

	diag_hand_rank_label = _make_label("HAND: --", 11, COLOR_RED)
	diagnostics_panel.add_child(diag_hand_rank_label)
	diag_payout_label = _make_label("PAYOUT: --", 11, COLOR_RED)
	diagnostics_panel.add_child(diag_payout_label)
	diag_du_trail_label = _make_label("DU TRAIL: []", 10, COLOR_BLUE)
	diag_du_trail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagnostics_panel.add_child(diag_du_trail_label)

	parent.add_child(diagnostics_panel)

func _refresh_diagnostics() -> void:
	if not diag_visible:
		return
	var fps := Engine.get_frames_per_second()
	diag_fps_label.text = "FPS: %d  (draw: %d)" % [fps, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	diag_memory_label.text = "MEM: %.1f MB static / %.1f MB video" % [
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0
	]

	var ping := 0
	if last_heartbeat_response_time > 0.0:
		ping = int((Time.get_unix_time_from_system() - last_heartbeat_response_time) * 1000.0)
	diag_ping_label.text = "PING: %d ms  (LAT: %d ms)" % [ping, max(0, ping)]
	diag_heartbeat_label.text = "HB LAST: %s  LIVE: %s" % [
		Time.get_datetime_string_from_unix_time(last_heartbeat_response_time) if last_heartbeat_response_time > 0.0 else "--",
		_connection_state_name(connection_state)
	]

	diag_machine_id_label.text = "MACHINE: %d" % configured_machine_id
	diag_session_id_label.text = "SESSION: %s" % store.session_id()
	diag_state_version_label.text = "STATE VER: %d" % store.state_version()
	diag_sequence_label.text = "SEQ: %d" % store.sequence_number()

	diag_hand_rank_label.text = "HAND: %s  (%s)" % [store.hand_rank(), store.game_state()]
	var win_amount = store.pending_win_amount()
	var multiplier: int = int(paytable_multipliers.get(_paytable_rank_key(store.hand_rank()), 0))
	diag_payout_label.text = "PAYOUT: %s (%dx stk)" % [_format_amount(win_amount), multiplier]

	var du_data := _double_up_data()
	var trail_json: String = JSON.stringify(_du_array(du_data, ["card_trail", "cardTrail", "CardTrail"]))
	diag_du_trail_label.text = "DU TRAIL: %s" % trail_json.left(200)

	diag_fps_accum = 0.0
	diag_fps_counter = 0

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
	_enter_connection_state(ConnectionState.CONNECTING)
	store.apply_transport_error(reason)
	_refresh_ui()
	api.post_login(auth_username, auth_password)

func _request_replay() -> void: api.post_replay(configured_machine_id, store.state_version(), store.sequence_number())

func _send_heartbeat() -> void:
	if access_token.is_empty() or store.snapshot.is_empty():
		return
	if connection_state != ConnectionState.LIVE and connection_state != ConnectionState.RECONNECTING:
		_check_heartbeat_timeout()
		return
	_check_heartbeat_timeout()
	_send_command("heartbeat", {}, false, false)

func _check_heartbeat_timeout() -> void:
	if last_heartbeat_response_time <= 0.0:
		return
	var now := Time.get_unix_time_from_system()
	var elapsed := now - last_heartbeat_response_time
	if elapsed > 30.0 and connection_state == ConnectionState.LIVE:
		_enter_connection_state(ConnectionState.RECONNECTING)
		_send_heartbeat()

func _enter_connection_state(state: int) -> void:
	var previous := connection_state
	connection_state = state
	match state:
		ConnectionState.OFFLINE:
			last_heartbeat_response_time = 0.0
		ConnectionState.CONNECTING:
			last_heartbeat_response_time = Time.get_unix_time_from_system()
		ConnectionState.SYNCING_SNAPSHOT:
			pass
		ConnectionState.LIVE:
			last_heartbeat_response_time = Time.get_unix_time_from_system()
		ConnectionState.RECONNECTING:
			pass
		ConnectionState.RECOVERY_REQUIRED:
			pass
	_refresh_connection_ui()
	if previous != state:
		_refresh_ui()

func _connection_state_name(state: int) -> String:
	match state:
		ConnectionState.OFFLINE: return "OFFLINE"
		ConnectionState.CONNECTING: return "CONNECTING"
		ConnectionState.SYNCING_SNAPSHOT: return "SYNCING"
		ConnectionState.LIVE: return "LIVE"
		ConnectionState.RECONNECTING: return "RECONNECTING"
		ConnectionState.RECOVERY_REQUIRED: return "RECOVERY REQUIRED"
	return "UNKNOWN"

func _is_connection_live() -> bool:
	return connection_state == ConnectionState.LIVE

func _refresh_connection_ui() -> void:
	var is_live := _is_connection_live()
	if recovery_overlay != null:
		recovery_overlay.visible = not is_live and not access_token.is_empty()
		if recovery_overlay_label != null:
			recovery_overlay_label.text = _connection_state_name(connection_state) if not is_live else ""
	if connection_state_label != null:
		connection_state_label.text = _connection_state_name(connection_state)

# ─── API response handler ───
func _on_api_response(kind: String, ok: bool, body, _status_code: int, error_message: String) -> void:
	if kind in ["admin_users", "admin_users_search", "admin_machines", "admin_agents", "admin_agent_create", "admin_agent_load_credit", "admin_agent_assign_user"]:
		_handle_admin_response(kind, ok, body, error_message)
		return

	if not ok:
		last_heartbeat_response_time = 0.0
		if _status_code == 401 and _has_auth_credentials():
			_reject_action_lock("", "Session lost")
			authenticating = false
			_enter_connection_state(ConnectionState.CONNECTING)
			_authenticate_and_sync("Session lost. Re-authenticating cabinet...")
			return
		if kind in ["login", "signup", "verify_otp"]:
			auth_status = _response_message(body, error_message)
			_refresh_ui(); return
		if kind == "command":
			_reject_action_lock("", error_message)
		store.apply_transport_error(error_message)
		if connection_state == ConnectionState.LIVE:
			_enter_connection_state(ConnectionState.RECONNECTING)
		_refresh_ui()
		if kind != "replay": replay_timer.start()
		return

	last_heartbeat_response_time = Time.get_unix_time_from_system()

	var data = _unwrap_response_data(body)
	if kind == "login" or kind == "refresh_token":
		_apply_login_response(body)
	elif kind == "signup":
		auth_status = _response_message(body, "SIGNUP OK - ENTER OTP"); _refresh_ui()
	elif kind == "verify_otp":
		auth_status = "OTP VERIFIED - LOGGING IN"; _refresh_ui()
		api.login(pending_signup_username, pending_signup_password)
	elif kind == "snapshot" and typeof(data) == TYPE_DICTIONARY:
		_enter_connection_state(ConnectionState.SYNCING_SNAPSHOT)
		_apply_snapshot(data)
	elif kind == "command" and typeof(data) == TYPE_DICTIONARY:
		_handle_command_response(data)
	elif kind == "replay" and typeof(data) == TYPE_DICTIONARY:
		if data.get("requires_full_snapshot", false) and data.has("snapshot"):
			_enter_connection_state(ConnectionState.SYNCING_SNAPSHOT)
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
		_enter_connection_state(ConnectionState.LIVE)
		_refresh_ui()

# ─── UI refresh ───
func _refresh_ui() -> void:
	_refresh_auth_panel()
	if title_label != null:
		title_label.text = ""
	_refresh_credit_display()
	var game_state := store.game_state()
	message_label.text = store.message()
	if game_state == "hold" and local_hold_indexes.is_empty() and not auto_holds_cancelled and not store.advised_hold_indexes().is_empty():
		message_label.text = "AUTO-HOLD SUGGESTED - DRAW OR ADJUST"
	recovery_label.text = "" if access_token.is_empty() or store.commands_allowed() else "RECOVERY: %s" % store.recovery_message()
	bet_label.text = "BET %s" % _format_amount(selected_bet)

	if last_game_state != game_state and game_state != "hold":
		local_hold_indexes.clear()
	last_game_state = game_state

	var du_data := _double_up_data()
	var raw_du_active := _is_double_up_active(du_data)
	var du_render_data := _double_up_render_data(du_data, raw_du_active)
	var du_active := raw_du_active or du_end_hold_active
	_maybe_auto_start_double_up(game_state, du_active)
	_refresh_card_area_layout(du_active)

	_refresh_cards(game_state, du_active)
	_refresh_du_panel(du_render_data, du_active)
	_refresh_jackpots()
	_refresh_machine_info()
	_refresh_win_display()
	_refresh_lucky5_banner()
	_refresh_menu_balance()
	admin_screen.visible = active_screen == "admin"
	if menu_overlay != null:
		menu_overlay.visible = menu_open and active_screen == "game"

	for id in action_buttons.keys():
		var button: Button = action_buttons[id]
		button.disabled = not _is_action_enabled(id)
		if id == "deal_draw" and not _button_uses_asset(button):
			button.text = "DEAL\nDRAW"

	var held_indexes := _visual_hold_indexes()
	var fh_switch := _can_switch_full_house_rank()
	for index in range(hold_buttons.size()):
		var hold_button: Button = hold_buttons[index]
		var held := held_indexes.has(index)
		hold_button.disabled = not _is_action_enabled("hold_%d" % index)
		hold_button.text = "HELD" if held else ("" if _button_uses_asset(hold_button) else ("FH" if fh_switch else "HOLD"))

	if diag_visible:
		_refresh_diagnostics()

func _double_up_render_data(du_data: Dictionary, raw_du_active: bool) -> Dictionary:
	if raw_du_active:
		if du_end_hold_timer != null:
			du_end_hold_timer.stop()
		du_end_hold_active = false
		du_end_hold_data.clear()
		du_last_active_data = du_data.duplicate(true)
		du_was_active = true
		return du_data

	if du_was_active and not du_last_active_data.is_empty():
		if not du_end_hold_active:
			var hold_source := du_data if _du_has_renderable_cards(du_data) else du_last_active_data
			du_end_hold_data = hold_source.duplicate(true)
			du_last_active_data = du_end_hold_data.duplicate(true)
			du_end_hold_active = true
			if du_end_hold_timer != null:
				du_end_hold_timer.stop()
				du_end_hold_timer.wait_time = DU_END_HOLD_SECONDS
				du_end_hold_timer.start()
		return du_end_hold_data

	return du_data

func _du_has_renderable_cards(du_data: Dictionary) -> bool:
	var dealer_code := _du_card_code(du_data, ["dealer_card", "dealerCard", "DealerCard", "double_up_card", "doubleUpCard", "DoubleUpCard"])
	if dealer_code.length() >= 2:
		return true
	return not _du_array(du_data, ["card_trail", "cardTrail", "CardTrail"]).is_empty()

func _on_du_end_hold_timeout() -> void:
	du_end_hold_active = false
	du_end_hold_data.clear()
	du_last_active_data.clear()
	du_was_active = false
	_refresh_ui()

func _sync_idle_fh_timer(is_blank_idle: bool) -> void:
	if idle_fh_timer == null:
		idle_fh_rank_revealed = is_blank_idle
		return
	if not is_blank_idle:
		idle_fh_rank_revealed = false
		idle_fh_timer.stop()
		return
	if idle_fh_rank_revealed:
		if not idle_fh_timer.is_stopped():
			idle_fh_timer.stop()
		return
	if idle_fh_timer.is_stopped():
		idle_fh_timer.start()

func _on_idle_fh_timer_timeout() -> void:
	idle_fh_rank_revealed = true
	_refresh_ui()

func _refresh_card_area_layout(du_active: bool) -> void:
	if card_area_panel == null:
		return
	card_area_panel.visible = true
	card_area_panel.custom_minimum_size = Vector2(0, CARD_AREA_MIN_HEIGHT)
	if card_container != null:
		card_container.visible = not du_active
	if du_trail_container != null:
		du_trail_container.visible = du_active

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
	# ai9 attract: show the big LUCKY5 POKER logo over the empty board while idle,
	# until the 60s timer reveals the full-house rank card easter egg.
	var show_idle_title := is_blank_idle and not idle_fh_rank_revealed
	var show_idle_rank_card := game_state == "idle" and not du_active and cards.is_empty() and not show_idle_title
	if idle_title_label != null:
		idle_title_label.visible = show_idle_title and not du_active
	if card_container != null:
		card_container.visible = not du_active and not show_idle_title
	if du_trail_container != null:
		du_trail_container.visible = du_active

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
	var mat := rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flip_progress", 0.0)
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
	var mat := rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flip_progress", 0.0)
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
	var mat := rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flip_progress", 0.0)
	_play_deal_whoosh()
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

	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flip_progress", 0.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "modulate", Color(1, 1, 1, 0.72), DRAW_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rect, "position", base_position, DRAW_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rect, "scale", Vector2(0.08, 1.02), DRAW_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if mat != null:
		var flip_tw := create_tween()
		flip_tw.tween_method(Callable(self, "_set_card_flip_progress").bind(rect), 0.0, 1.0, DRAW_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(Callable(self, "_finish_card_draw_replacement").bind(index, code, texture, bool(reveal.get("held", false)), base_position))
	slot["tween"] = tw

func _finish_card_draw_replacement(index: int, code: String, texture: Texture2D, held: bool, base_position: Vector2) -> void:
	if index < 0 or index >= cards_texture_rects.size():
		return
	var slot: Dictionary = cards_texture_rects[index]
	var rect: TextureRect = slot["rect"]
	slot["tween"] = null
	rect.texture = texture
	rect.position = base_position
	rect.scale = Vector2(0.08, 1.02)
	rect.modulate = Color(1, 1, 1, 0.72)
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

	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flip_progress", 1.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "modulate", Color(1, 1, 1, 1), DRAW_IN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "position", base_position, DRAW_IN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "scale", Vector2(1.03, 1.0), DRAW_IN_DURATION * 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(rect, "scale", Vector2(1.0, 1.0), DRAW_IN_DURATION * 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if mat != null:
		var flip_tw := create_tween()
		flip_tw.tween_method(Callable(self, "_set_card_flip_progress").bind(rect), 1.0, 0.0, DRAW_IN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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

	rect.modulate = Color(1, 1, 1, 0.70)
	rect.pivot_offset = rect.custom_minimum_size * 0.5
	var base_position := rect.position
	rect.position = base_position
	rect.scale = Vector2(0.08, 1.02)

	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flip_progress", 0.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "modulate", Color(1, 1, 1, 1), DEAL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "position", base_position, DEAL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "scale", Vector2(1.04, 1.0), DEAL_DURATION * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(rect, "scale", Vector2(1.0, 1.0), DEAL_DURATION * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if mat != null:
		var flip_tw := create_tween()
		flip_tw.tween_method(Callable(self, "_set_card_flip_progress").bind(rect), 0.0, 1.0, DEAL_DURATION * 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		flip_tw.tween_method(Callable(self, "_set_card_flip_progress").bind(rect), 1.0, 0.0, DEAL_DURATION * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	slot["tween"] = tw

func _set_card_flip_progress(value: float, rect: TextureRect) -> void:
	var mat := rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flip_progress", value)

func _refresh_du_panel(du_data: Dictionary, du_active: bool) -> void:
	du_info_panel.visible = du_active
	if not du_active:
		if du_shuffle_timer != null:
			du_shuffle_timer.stop()
		du_shuffle_replace_dealer_only = false
		if du_promote_timer != null:
			du_promote_timer.stop()
		_clear_du_board()
		_clear_du_pending_promotion()
		du_local_trail_entries.clear()
		_prev_dealer_code = ""
		_prev_challenger_code = ""
		_prev_switches_remaining = -1
		du_last_switch_dealer_code = ""
		return

	var status := _du_status(du_data)
	var switches := _du_switches_remaining(du_data)
	du_switch_node.text = "SWAPS: %d" % switches if switches > 0 else ""

	var dealer_code := _du_card_code(du_data, ["dealer_card", "dealerCard", "DealerCard", "double_up_card", "doubleUpCard", "DoubleUpCard"])
	var challenger_code := _du_card_code(du_data, ["challenger_card", "challengerCard", "ChallengerCard", "picked_card", "pickedCard", "PickedCard"])

	var dealer_changed := not dealer_code.is_empty() and _prev_dealer_code != "" and _prev_dealer_code != dealer_code
	var challenger_changed := not challenger_code.is_empty() and _prev_challenger_code != challenger_code
	var command_switched_dealer := (pending_command_type == "double_up_switch" or pending_command_type == "swap_double_up_card") and challenger_code.is_empty() and dealer_changed
	var switch_count_decreased := _prev_switches_remaining >= 0 and switches < _prev_switches_remaining
	var switch_replaced_dealer := challenger_code.is_empty() and dealer_changed and (switch_count_decreased or command_switched_dealer)
	var inferred_win_reveal := challenger_code.is_empty() and dealer_changed and not switch_replaced_dealer
	var board_dealer_code := _prev_dealer_code if ((inferred_win_reveal or switch_replaced_dealer) and not _prev_dealer_code.is_empty()) else dealer_code
	var board_challenger_code := dealer_code if inferred_win_reveal else challenger_code
	var board_status := "Win" if inferred_win_reveal else status

	_prepare_du_board(du_data, board_dealer_code, board_challenger_code, board_status, switch_replaced_dealer)

	if switch_replaced_dealer:
		if du_promote_timer != null:
			du_promote_timer.stop()
		_clear_du_pending_promotion()
		du_last_switch_dealer_code = dealer_code
		_start_du_dealer_replace_shuffle(dealer_code)
	elif inferred_win_reveal:
		du_last_switch_dealer_code = ""
		if du_promote_timer != null:
			du_promote_timer.stop()
		_start_du_card_shuffle(board_dealer_code, board_challenger_code)
		_queue_du_dealer_promotion(board_challenger_code, board_dealer_code)
	elif challenger_code.is_empty():
		if du_promote_timer != null:
			du_promote_timer.stop()
		_clear_du_pending_promotion()
		_set_du_card_texture(du_dealer_rect, dealer_code)
		var showing_switched_dealer := not du_last_switch_dealer_code.is_empty() and du_last_switch_dealer_code == dealer_code
		if not showing_switched_dealer and (du_shuffle_timer == null or du_shuffle_timer.is_stopped() or not du_shuffle_target_challenger.is_empty()):
			_start_du_card_shuffle(dealer_code, "")
	elif dealer_changed or challenger_changed:
		du_last_switch_dealer_code = ""
		_start_du_card_shuffle(dealer_code, challenger_code)
		if challenger_changed and _du_should_promote_after_reveal(status, challenger_code):
			_queue_du_dealer_promotion(challenger_code, dealer_code)
	else:
		if du_shuffle_timer != null and not du_shuffle_timer.is_stopped():
			du_shuffle_timer.stop()
		du_shuffle_replace_dealer_only = false
		_set_du_card_texture(du_dealer_rect, dealer_code)
		_set_du_card_texture(du_challenger_rect, challenger_code)

	_prev_dealer_code = dealer_code
	_prev_challenger_code = challenger_code
	_prev_switches_remaining = switches

	var is_lucky5 := _du_bool(du_data, ["is_lucky5_active", "isLucky5Active", "IsLucky5Active", "lucky5", "Lucky5", "winLucky5", "WinLucky5"])
	var is_no_lose := _du_bool(du_data, ["is_no_lose_active", "isNoLoseActive", "IsNoLoseActive"])
	du_lucky_node.text = "5♠ NEVER LOSE"
	du_lucky_node.add_theme_color_override("font_color", COLOR_GREEN if is_lucky5 or is_no_lose else COLOR_BLUE)
	du_guess_node.text = "HI OR LO"

func _prepare_du_board(du_data: Dictionary, dealer_code: String, challenger_code: String, status: String, dealer_replace_only: bool = false) -> void:
	_clear_du_board()

	_refresh_du_trail(du_data, dealer_code, challenger_code, status, dealer_replace_only)

func _refresh_du_trail(du_data: Dictionary, dealer_code: String, challenger_code: String, status: String, dealer_replace_only: bool = false) -> void:
	var slot_count := du_cards.size()
	if slot_count <= 0:
		return

	var page_entries := []
	if dealer_replace_only:
		if dealer_code.length() >= 2:
			page_entries.append({"code": dealer_code, "label": "DEALER"})
	else:
		page_entries = _du_visible_page_entries(du_data, dealer_code, challenger_code, slot_count)

	var dealer_index := _du_page_entry_index(page_entries, dealer_code)
	if dealer_index < 0 and dealer_code.length() >= 2:
		if page_entries.size() >= slot_count:
			page_entries.clear()
		page_entries.append({"code": dealer_code, "label": "DEALER"})
		dealer_index = page_entries.size() - 1
	if dealer_index < 0:
		dealer_index = 0

	var challenger_index := -1
	if challenger_code.length() >= 2:
		challenger_index = _du_page_entry_index_after(page_entries, challenger_code, dealer_index)
		if challenger_index < 0:
			challenger_index = _du_page_entry_index(page_entries, challenger_code)

	var reveal_index: int = challenger_index if challenger_index >= 0 else min(dealer_index + 1, slot_count - 1)

	for slot_index in range(slot_count):
		if slot_index < page_entries.size():
			var entry: Dictionary = page_entries[slot_index]
			var code := str(entry.get("code", ""))
			var label := ""
			if slot_index == dealer_index:
				label = "DEALER"
			elif slot_index == challenger_index:
				label = _du_result_label(status)
			_set_du_board_slot(slot_index, code, label, _is_lucky_du_card(du_data, code))
		elif slot_index == reveal_index and dealer_code.length() >= 2:
			_set_du_board_back(slot_index, "BIG / SMALL ?", 1.0)
		else:
			_set_du_board_back(slot_index, "", 0.18)

	_set_du_dealer_slot(dealer_index)
	_set_du_challenger_slot(reveal_index)

func _du_visible_deck_codes(du_data: Dictionary, dealer_code: String, challenger_code: String, max_count: int) -> Array:
	var result: Array = []
	if max_count <= 0:
		return result
	for entry in _du_visible_page_entries(du_data, dealer_code, challenger_code, max_count):
		result.append(str(entry.get("code", "")))
	return result

func _du_visible_hit_codes(du_data: Dictionary, dealer_code: String, challenger_code: String, max_count: int) -> Array:
	var result: Array = []
	if max_count <= 0:
		return result
	for entry in _du_visible_page_entries(du_data, dealer_code, challenger_code, max_count):
		var code := str(entry.get("code", ""))
		if code.length() >= 2 and code != dealer_code and code != challenger_code:
			result.append(code)
	return result

func _du_visible_page_entries(du_data: Dictionary, dealer_code: String, challenger_code: String, slot_count: int) -> Array:
	if slot_count <= 0:
		return []
	var timeline := _du_timeline_entries(du_data)
	var dealer_position := _du_page_entry_index(timeline, dealer_code)
	if dealer_position < 0 and dealer_code.length() >= 2:
		timeline.append({"code": dealer_code, "label": "DEALER"})
		dealer_position = timeline.size() - 1
	if dealer_position < 0:
		return []

	while timeline.size() > dealer_position + 1:
		timeline.remove_at(timeline.size() - 1)

	if challenger_code.length() >= 2 and _du_page_entry_index_after(timeline, challenger_code, dealer_position) < 0:
		timeline.append({"code": challenger_code, "label": "REVEAL"})

	var page_start := _du_page_start_for_dealer_index(dealer_position, slot_count)
	var result: Array = []
	for index in range(page_start, timeline.size()):
		if result.size() >= slot_count:
			break
		result.append(timeline[index])
	return result

func _du_timeline_entries(du_data: Dictionary) -> Array:
	var result: Array = []
	var has_local_trail := not du_local_trail_entries.is_empty()
	var trail_source := du_local_trail_entries if has_local_trail else _du_array(du_data, ["card_trail", "cardTrail", "CardTrail"])
	if typeof(trail_source) == TYPE_ARRAY:
		for entry in trail_source:
			var code := _du_entry_code(entry)
			_append_du_timeline_entry(result, code, _du_entry_label(entry))
	return result

func _du_page_start_for_dealer_index(dealer_position: int, slot_count: int) -> int:
	# AI9 pages reuse the fifth card as slot 0 of the next deck row.
	var stride: int = max(1, slot_count - 1)
	if dealer_position < stride:
		return 0
	return int(floor(float(dealer_position) / float(stride))) * stride

func _du_page_entry_index(entries: Array, code: String) -> int:
	if code.length() < 2:
		return -1
	for index in range(entries.size()):
		if typeof(entries[index]) != TYPE_DICTIONARY:
			continue
		if str((entries[index] as Dictionary).get("code", "")) == code:
			return index
	return -1

func _du_page_entry_index_after(entries: Array, code: String, start_after: int) -> int:
	if code.length() < 2:
		return -1
	for index in range(max(0, start_after + 1), entries.size()):
		if typeof(entries[index]) != TYPE_DICTIONARY:
			continue
		if str((entries[index] as Dictionary).get("code", "")) == code:
			return index
	return -1

func _du_current_round_index(du_data: Dictionary) -> int:
	return max(0, store._to_int(_du_first_value(du_data, ["current_round_index", "currentRoundIndex", "CurrentRoundIndex", "double_up_count", "doubleUpCount", "DoubleUpCount"], 0)))

func _append_du_timeline_entry(entries: Array, code: String, label_text: String) -> void:
	if code.length() < 2 or _du_trail_contains_code(entries, code):
		return
	var label := label_text.strip_edges().to_upper()
	if label.is_empty() or label == "DEALER":
		label = "PLAYED"
	entries.append({"code": code, "label": label})

func _du_trail_contains_code(entries: Array, code: String) -> bool:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str((entry as Dictionary).get("code", "")) == code:
			return true
	return false

func _append_du_local_trail_entry(code: String, label_text: String = "PLAYED") -> void:
	if code.length() < 2:
		return
	for entry in du_local_trail_entries:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("code", "")) == code:
			return
	var label := label_text.strip_edges().to_upper()
	if label.is_empty() or label == "DEALER":
		label = "PLAYED"
	du_local_trail_entries.append({"code": code, "label": label})

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

func _du_entry_label(entry: Variant) -> String:
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	var entry_dict: Dictionary = entry
	var raw_label: Variant = _du_first_value(entry_dict, ["label", "Label", "status", "Status"], "")
	return str(raw_label).strip_edges().to_upper()

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

func _clear_du_pending_promotion() -> void:
	du_pending_promote_dealer = ""
	du_pending_promote_trail_code = ""
	du_pending_promote_trail_label = ""

func _queue_du_dealer_promotion(next_dealer_code: String, trail_code: String = "", trail_label: String = "PLAYED") -> void:
	if next_dealer_code.length() < 2:
		return
	du_pending_promote_dealer = next_dealer_code
	du_pending_promote_trail_code = trail_code
	du_pending_promote_trail_label = trail_label
	if du_promote_timer != null:
		du_promote_timer.stop()
		du_promote_timer.wait_time = DU_REVEAL_SETTLE_SECONDS
		du_promote_timer.start()

func _on_du_promote_timeout() -> void:
	if du_pending_promote_dealer.length() < 2:
		return
	var next_dealer_code := du_pending_promote_dealer
	var trail_code := du_pending_promote_trail_code
	var trail_label := du_pending_promote_trail_label
	var du_data := _double_up_data()
	if not _is_double_up_active(du_data):
		_clear_du_pending_promotion()
		return
	if not _du_should_promote_after_reveal(_du_status(du_data), next_dealer_code):
		_clear_du_pending_promotion()
		return
	_append_du_local_trail_entry(trail_code, trail_label)
	_prepare_du_board(du_data, next_dealer_code, "", _du_status(du_data), false)
	_start_du_card_shuffle(next_dealer_code, "")
	_clear_du_pending_promotion()

func _is_lucky_du_card(du_data: Dictionary, code: String) -> bool:
	return code == "5S" and (
		_du_bool(du_data, ["is_lucky5_active", "isLucky5Active", "IsLucky5Active", "lucky5", "Lucky5", "winLucky5", "WinLucky5"])
		or _du_bool(du_data, ["is_no_lose_active", "isNoLoseActive", "IsNoLoseActive"])
	)

func _clear_du_board() -> void:
	for index in range(du_cards.size()):
		_set_du_board_back(index, "", 0.34)
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
	du_dealer_rect = null
	du_dealer_label = null
	du_challenger_rect = null
	du_challenger_label = null

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
	if new_player_code.is_empty():
		_start_du_dealer_replace_shuffle(new_dealer_code)
	else:
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
	du_shuffle_replace_dealer_only = false
	du_shuffle_ticks_remaining = DU_SHUFFLE_TICKS if new_player_code.length() >= 2 else -1
	du_shuffle_index = 0
	_set_du_card_texture(du_dealer_rect, new_dealer_code)
	if du_challenger_label != null and new_player_code.is_empty():
		du_challenger_label.text = "BIG / SMALL ?"
		du_challenger_label.add_theme_color_override("font_color", COLOR_GOLD)
	du_challenger_rect.modulate = Color(1, 1, 1, 1)
	du_challenger_rect.scale = Vector2(0.92, 0.92)
	_process_du_shuffle()
	if du_shuffle_timer != null and du_shuffle_timer.is_stopped():
		du_shuffle_timer.start()

func _start_du_dealer_replace_shuffle(new_dealer_code: String) -> void:
	if du_dealer_rect == null or du_challenger_rect == null:
		return
	if du_shuffle_timer != null:
		du_shuffle_timer.stop()
	du_shuffle_replace_dealer_only = false
	if du_dealer_label != null:
		du_dealer_label.text = "DEALER"
		du_dealer_label.add_theme_color_override("font_color", COLOR_BLUE)
	if du_challenger_label != null:
		du_challenger_label.text = "BIG / SMALL ?"
		du_challenger_label.add_theme_color_override("font_color", COLOR_GOLD)
	_set_du_card_texture(du_dealer_rect, new_dealer_code)
	du_dealer_rect.scale = Vector2(0.90, 0.90)
	var tw := create_tween()
	tw.tween_property(du_dealer_rect, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	du_challenger_rect.texture = _card_back_texture(false)
	du_challenger_rect.modulate = Color(1, 1, 1, 1.0)
	du_challenger_rect.scale = Vector2(1.0, 1.0)

func _process_du_shuffle() -> void:
	var code: String = DU_SHUFFLE_CODES[du_shuffle_index % DU_SHUFFLE_CODES.size()]
	du_shuffle_index += 1
	var target_rect: TextureRect = du_dealer_rect if du_shuffle_replace_dealer_only else du_challenger_rect
	if target_rect == null:
		target_rect = du_dealer_rect
	_set_du_card_texture(target_rect, code)
	_play_shuffle_tick()
	if du_shuffle_ticks_remaining > 0:
		du_shuffle_ticks_remaining -= 1
		if du_shuffle_ticks_remaining <= 0:
			_finish_du_card_shuffle()

func _finish_du_card_shuffle() -> void:
	if du_shuffle_timer != null:
		du_shuffle_timer.stop()
	_set_du_card_texture(du_dealer_rect, du_shuffle_target_dealer)
	if du_shuffle_replace_dealer_only:
		if du_challenger_rect != null:
			du_challenger_rect.texture = _card_back_texture(false)
			du_challenger_rect.modulate = Color(1, 1, 1, 1.0)
			du_challenger_rect.scale = Vector2(1.0, 1.0)
		if du_dealer_rect != null:
			du_dealer_rect.scale = Vector2(0.92, 0.92)
			var dealer_tw := create_tween()
			dealer_tw.tween_property(du_dealer_rect, "scale", Vector2(1.0, 1.0), DU_SWITCH_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		du_shuffle_replace_dealer_only = false
		return
	_set_du_card_texture(du_challenger_rect, du_shuffle_target_challenger)
	if du_shuffle_target_challenger.length() >= 2 and du_challenger_rect != null:
		du_challenger_rect.scale = Vector2(0.92, 0.92)
		var tw := create_tween()
		tw.tween_property(du_challenger_rect, "scale", Vector2(1.0, 1.0), DU_SWITCH_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _refresh_jackpots() -> void:
	var jp: Dictionary = store.snapshot.get("jackpot", {})
	var active_4k: String = str(jp.get("active_four_of_a_kind_slot", "A"))
	_refresh_jackpot_counter("4k-a", jp.get("four_of_a_kind_a", 0))
	_refresh_jackpot_counter("sf", jp.get("straight_flush", 0))
	_refresh_jackpot_counter("4k-b", jp.get("four_of_a_kind_b", 0))
	_set_jackpot_counter_active("4k-a", active_4k == "A")
	_set_jackpot_counter_active("4k-b", active_4k == "B")
	_refresh_paytable_values()
	_refresh_paytable_highlights()
	_refresh_bonus_stage()

func _refresh_jackpot_counter(slot_key: String, target_value) -> void:
	if not jackpot_counters.has(slot_key):
		return
	var target := store._to_int(target_value)
	var running: Tween = jackpot_counter_tweens.get(slot_key, null)
	if running != null and running.is_valid() and jackpot_counter_targets.get(slot_key, target) == target:
		return
	if not displayed_jackpots.has(slot_key):
		jackpot_counter_targets[slot_key] = target
		_set_jackpot_counter_display(float(target), slot_key)
		return
	var current := int(displayed_jackpots.get(slot_key, target))
	if current == target:
		jackpot_counter_targets[slot_key] = target
		_set_jackpot_counter_display(float(target), slot_key)
		return
	_animate_jackpot_counter(slot_key, current, target)

func _animate_jackpot_counter(slot_key: String, from_value: int, to_value: int) -> void:
	var existing: Tween = jackpot_counter_tweens.get(slot_key, null)
	if existing != null and existing.is_valid():
		existing.kill()
	jackpot_counter_targets[slot_key] = to_value
	var draining := to_value < from_value
	var duration := JACKPOT_DRAIN_DURATION if draining else JACKPOT_TRICKLE_DURATION
	var tw := create_tween()
	tw.tween_method(Callable(self, "_set_jackpot_counter_display").bind(slot_key), float(from_value), float(to_value), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var panel: Panel = jackpot_counter_panels.get(slot_key, null)
	if panel != null:
		panel.modulate = Color(1.0, 0.42, 0.24, 1.0) if draining else Color(1.0, 1.0, 0.55, 1.0)
		tw.parallel().tween_property(panel, "modulate", Color.WHITE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func ():
		displayed_jackpots[slot_key] = to_value
		jackpot_counter_targets[slot_key] = to_value
		jackpot_counter_tweens.erase(slot_key)
	)
	jackpot_counter_tweens[slot_key] = tw

func _set_jackpot_counter_display(value: float, slot_key: String) -> void:
	var amount := int(round(value))
	displayed_jackpots[slot_key] = amount
	var label: Label = jackpot_counters.get(slot_key, null)
	if label != null:
		if slot_key == "sf":
			label.text = "\u00A2 %s" % _format_amount(amount)
		else:
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
	if bonus_stage_label == null or bonus_stage_amount_label == null:
		return
	var bonus: Dictionary = _bonus_presentation()
	var active := _du_bool(bonus, ["active", "isActive", "Active"])
	if not active:
		var fallback := _fallback_bonus_presentation()
		if _du_bool(fallback, ["active", "isActive", "Active"]):
			bonus = fallback
			active = true

	var kind := str(_du_first_value(bonus, ["kind", "Kind"], "free_games"))
	var amount := store._to_int(_du_first_value(bonus, ["amount", "Amount", "current_amount", "currentAmount", "CurrentAmount"], 0))
	var free_count := store._to_int(_du_first_value(bonus, ["free_game_count", "freeGameCount", "FreeGameCount"], 0))
	var message := str(_du_first_value(bonus, ["message", "Message"], "FREE GAMES BONUS"))

	if bonus_message_label != null:
		bonus_message_label.text = message if active else "4 OF A KIND   WINS BONUS"
		bonus_message_label.add_theme_color_override("font_color", COLOR_GOLD if active else COLOR_WHITE)

	bonus_stage_label.visible = active
	bonus_stage_amount_label.visible = active

	match kind:
		"lucky5":
			bonus_stage_label.text = "FREE GAMES 000"
			bonus_stage_label.add_theme_color_override("font_color", COLOR_GOLD)
		"bonus_card":
			bonus_stage_label.text = "BONUS CARD"
			bonus_stage_label.add_theme_color_override("font_color", COLOR_GOLD)
		_:
			if free_count > 0:
				bonus_stage_label.text = "FREE GAMES %03d" % free_count
			else:
				bonus_stage_label.text = "FREE GAMES 000"
			bonus_stage_label.add_theme_color_override("font_color", COLOR_RED if active else COLOR_GOLD)

	if active and amount > 0:
		bonus_stage_amount_label.text = "%s" % _format_amount(amount)
		bonus_stage_amount_label.add_theme_color_override("font_color", COLOR_RED)
	elif free_count > 0 and kind != "lucky5":
		bonus_stage_amount_label.text = ""
	else:
		bonus_stage_amount_label.text = "BONUS 0"
		bonus_stage_amount_label.add_theme_color_override("font_color", COLOR_WHITE)

func _bonus_presentation() -> Dictionary:
	var presentation: Dictionary = store.snapshot.get("presentation", {})
	var bonus: Variant = _du_first_value(presentation, ["bonus", "Bonus"], {})
	if typeof(bonus) == TYPE_DICTIONARY:
		return bonus
	return {}

func _fallback_bonus_presentation() -> Dictionary:
	var du: Dictionary = _double_up_data()
	if _is_double_up_state_name(store.game_state()) and _du_bool(du, ["is_lucky5_active", "isLucky5Active", "IsLucky5Active"]):
		return {
			"active": true,
			"kind": "lucky5",
			"card_code": "5S",
			"amount": _du_first_value(du, ["current_amount", "currentAmount", "CurrentAmount"], 0),
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

func _full_house_rank_text() -> String:
	var jp: Dictionary = _jackpot_data()
	var rank: Variant = _du_first_value(jp, ["full_house_rank", "fullHouseRank", "FullHouseRank"], 0)
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
	var jp: Dictionary = _jackpot_data()
	var rank: Variant = _du_first_value(jp, ["full_house_rank", "fullHouseRank", "FullHouseRank"], 0)
	var rank_value: int = store._to_int(rank)
	match rank_value:
		14: return "AS"
		13: return "KS"
		12: return "QS"
		11: return "JS"
		10: return "10S"
		_: return str(max(2, rank_value)) + "S" if rank_value > 0 else "AS"

func _four_kind_rank_card_code() -> String:
	var cards := store.result_cards()
	if cards.is_empty():
		cards = store.cards()
	var rank_counts: Dictionary = {}
	var rank_sample: Dictionary = {}
	for entry in cards:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var code := str((entry as Dictionary).get("code", ""))
		if code.length() < 2:
			continue
		var rank := code.substr(0, code.length() - 1)
		rank_counts[rank] = int(rank_counts.get(rank, 0)) + 1
		if not rank_sample.has(rank):
			rank_sample[rank] = code
	for rank in rank_counts.keys():
		if int(rank_counts[rank]) >= 4:
			return str(rank_sample[rank])
	return "AS"

func _refresh_paytable_values() -> void:
	if full_house_jackpot_label == null or full_house_rank_label == null: return
	var stake: int = max(0, store.stake())
	var score_key := win_paytable_rank_key
	if score_key.is_empty() and win_displayed_amount > 0:
		score_key = _paytable_rank_key(store.hand_rank())
	for key in paytable_amount_labels.keys():
		var amount_l: Label = paytable_amount_labels.get(key, null)
		if amount_l == null: continue
		if win_displayed_amount > 0 and str(key) == score_key:
			amount_l.text = "+%s" % _format_amount(win_displayed_amount)
			amount_l.add_theme_color_override("font_color", COLOR_GOLD)
			continue
		var multiplier: int = int(paytable_multipliers.get(key, 0))
		amount_l.text = _format_amount(stake * multiplier)
		amount_l.add_theme_color_override("font_color", paytable_amount_colors.get(str(key), COLOR_WHITE))
	var jp: Dictionary = _jackpot_data()
	_refresh_jackpot_counter("fh", store._to_int(_du_first_value(jp, ["full_house", "fullHouse", "FullHouse"], 0)))
	full_house_rank_label.text = _full_house_rank_text()

func _refresh_paytable_highlights() -> void:
	var hand_rank: String = _paytable_rank_key(store.hand_rank())
	var score_key := win_paytable_rank_key
	if score_key.is_empty() and win_displayed_amount > 0:
		score_key = _paytable_rank_key(hand_rank)
	for key in paytable_rows.keys():
		var row_panel: PanelContainer = paytable_rows.get(key, null)
		if row_panel == null: continue
		var sty := row_panel.get_theme_stylebox("panel", "") as StyleBoxFlat
		if sty == null: continue
		var highlighted: bool = str(key) == hand_rank or (win_displayed_amount > 0 and str(key) == score_key)
		
		var row_box := row_panel.get_child(0) as HBoxContainer
		var name_label := row_box.get_child(0) as Label
		
		if highlighted:
			sty.bg_color = Color(1.0, 0.86, 0.16, 0.36)
			sty.border_color = COLOR_GOLD
			sty.border_width_left = 1; sty.border_width_right = 1
			sty.border_width_top = 1; sty.border_width_bottom = 1
			
			var label_style := StyleBoxFlat.new()
			label_style.bg_color = Color.WHITE
			label_style.content_margin_left = 6
			label_style.content_margin_right = 6
			label_style.content_margin_top = 1
			label_style.content_margin_bottom = 1
			name_label.add_theme_stylebox_override("normal", label_style)
			name_label.add_theme_color_override("font_color", Color.BLACK)
		else:
			sty.bg_color = Color(0, 0, 0, 0)
			sty.border_color = Color(0, 0, 0, 0)
			sty.border_width_left = 0; sty.border_width_right = 0
			sty.border_width_top = 0; sty.border_width_bottom = 0
			
			name_label.remove_theme_stylebox_override("normal")
			name_label.add_theme_color_override("font_color", paytable_amount_colors.get(str(key), COLOR_WHITE))
		row_panel.queue_redraw()

func _refresh_machine_info() -> void:
	var machine: Dictionary = store.snapshot.get("machine", {})
	machine_serie_label.text = "SERIE %s" % str(machine.get("machine_serie", "0"))
	machine_kent_label.text = "KENT /3 : %s" % str(machine.get("machine_kent", "0"))
	machine_serial_label.text = "S/N: %s" % str(machine.get("machine_serial", "0"))
	if bonus_message_label != null:
		bonus_message_label.visible = true

func _refresh_credit_display() -> void:
	if stake_value_label != null:
		stake_value_label.text = _format_amount(max(0, store.stake()))
	if credit_value_label == null:
		return
	var machine_credits := store.machine_credits()
	if displayed_machine_credit_amount < 0:
		_set_credit_display_amount(machine_credits)
		credit_target_amount = machine_credits
		last_machine_credit_amount = machine_credits
		return
	if credit_transfer_active:
		if machine_credits != credit_target_amount:
			_animate_credit_transfer(displayed_machine_credit_amount, machine_credits, max(win_displayed_amount, win_target_amount))
		return

	var credit_gain: int = machine_credits - displayed_machine_credit_amount
	var visible_win: int = max(win_displayed_amount, win_target_amount)
	var jackpot_win: int = _current_jackpot_win_amount()
	if credit_gain > 0 and jackpot_win > 0:
		var drain_amount: int = max(jackpot_win, max(visible_win, credit_gain))
		_animate_credit_transfer(displayed_machine_credit_amount, machine_credits, drain_amount)
		return
	var settling_score := pending_command_type == "take_score" or pending_command_type == "cash_out"
	if credit_gain > 0 and settling_score:
		var drain_amount: int = visible_win if visible_win > 0 else credit_gain
		_animate_credit_transfer(displayed_machine_credit_amount, machine_credits, drain_amount)
		return

	_set_credit_display_amount(machine_credits)
	credit_target_amount = machine_credits
	if last_machine_credit_amount >= 0 and machine_credits > last_machine_credit_amount:
		_pulse_credit_display()
	last_machine_credit_amount = machine_credits

func _credit_line_for_amount(machine_credit_amount: int) -> String:
	return "CREDIT %s" % _format_amount(machine_credit_amount)

func _menu_balance_line() -> String:
	return "CREDIT %s\nWALLET %s\nBONUS %s\nSTAKE %s\nIN %s" % [
		_format_amount(store.machine_credits()),
		_format_amount(store.wallet_balance()),
		_format_amount(store.credit_balance()),
		_format_amount(store.stake()),
		_format_amount(store.total_cash_in())
	]

func _refresh_menu_balance() -> void:
	if menu_balance_label == null:
		return
	menu_balance_label.text = _menu_balance_line()

func _set_credit_display_amount(value: Variant) -> void:
	displayed_machine_credit_amount = max(0, int(round(float(value))))
	if credit_value_label == null:
		return
	credit_value_label.text = _credit_line_for_amount(displayed_machine_credit_amount)

func _current_jackpot_win_amount() -> int:
	var eval: Dictionary = _evaluation_data()
	return store._to_int(_du_first_value(eval, ["jackpot_won", "jackpotWon", "JackpotWon"], 0))

func _animate_credit_transfer(from_amount: int, to_amount: int, drain_amount: int) -> void:
	if credit_counter_tween != null and credit_counter_tween.is_valid():
		credit_counter_tween.kill()
	if win_counter_tween != null and win_counter_tween.is_valid():
		win_counter_tween.kill()

	credit_transfer_active = true
	credit_target_amount = max(0, to_amount)
	win_target_amount = 0
	var start_credit: int = max(0, from_amount)
	var start_win: int = max(max(0, drain_amount), max(win_displayed_amount, win_target_amount))
	var duration := _settlement_drain_duration(start_win)

	var eval: Dictionary = _evaluation_data()
	win_paytable_rank_key = _paytable_rank_key(str(_du_first_value(eval, ["hand_rank", "handRank", "HandRank"], store.hand_rank())))
	if win_slot_label != null:
		win_slot_label.text = win_paytable_rank_key

	credit_counter_tween = create_tween()
	credit_counter_tween.set_parallel(true)
	credit_counter_tween.tween_method(Callable(self, "_set_credit_display_amount"), float(start_credit), float(credit_target_amount), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	credit_counter_tween.tween_method(Callable(self, "_set_win_display_amount"), float(start_win), 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	credit_counter_tween.finished.connect(_on_credit_transfer_finished)
	_pulse_credit_display()
	_pulse_win_display()
	_start_credit_trickle_audio(duration)

func _settlement_drain_duration(amount: int) -> float:
	var eval: Dictionary = _evaluation_data()
	var jackpot_won := _current_jackpot_win_amount()
	var hand_rank := str(_du_first_value(eval, ["hand_rank", "handRank", "HandRank"], ""))
	if jackpot_won > 0 or hand_rank == "RoyalFlush":
		return CREDIT_DRAIN_JACKPOT_DURATION
	return clampf(float(abs(amount)) / 12000000.0, CREDIT_DRAIN_MIN_DURATION, CREDIT_DRAIN_MAX_DURATION)

func _start_credit_trickle_audio(duration: float) -> void:
	if credit_trickle_player == null:
		return
	_play_credit_trickle()
	var trickle_timer := Timer.new()
	trickle_timer.name = "CreditTrickleTimer"
	trickle_timer.wait_time = max(0.08, duration / 30.0)
	trickle_timer.one_shot = false
	trickle_timer.timeout.connect(_on_credit_trickle_tick.bind(trickle_timer, 0, int(duration / max(0.08, duration / 30.0))))
	add_child(trickle_timer)
	trickle_timer.start()

func _on_credit_trickle_tick(timer: Timer, _bound_tick: int, max_ticks: int) -> void:
	if not credit_transfer_active or credit_trickle_player == null:
		timer.queue_free()
		return
	_play_credit_trickle()
	var tick := timer.get_meta("trickle_tick", 0) as int
	var progress := float(tick) / float(max(1, max_ticks))
	timer.wait_time = max(0.04, 0.08 * (1.0 - progress * 0.6))
	timer.set_meta("trickle_tick", tick + 1)
	if tick >= max_ticks - 1:
		timer.queue_free()

func _stop_credit_trickle_audio() -> void:
	if credit_trickle_player != null:
		credit_trickle_player.stop()

func _on_credit_transfer_finished() -> void:
	credit_transfer_active = false
	_stop_credit_trickle_audio()
	_set_credit_display_amount(credit_target_amount)
	last_machine_credit_amount = credit_target_amount
	_set_win_display_amount(0)
	_on_win_counter_finished()
	_pulse_credit_display()

func _pulse_credit_display() -> void:
	var pulse_target: Label = credit_value_label if credit_value_label != null else credit_label
	if pulse_target == null:
		return
	if credit_pulse_tween != null and credit_pulse_tween.is_valid():
		credit_pulse_tween.kill()
	pulse_target.pivot_offset = pulse_target.size * 0.5
	pulse_target.scale = Vector2(1.05, 1.05)
	credit_pulse_tween = create_tween()
	credit_pulse_tween.tween_property(pulse_target, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _refresh_win_display() -> void:
	if credit_transfer_active:
		return
	var pending := store.pending_win_amount()
	var eval: Dictionary = _evaluation_data()
	if pending > 0:
		win_paytable_rank_key = _paytable_rank_key(str(_du_first_value(eval, ["hand_rank", "handRank", "HandRank"], store.hand_rank())))
		if win_slot_label != null:
			win_slot_label.text = win_paytable_rank_key
		if pending != win_target_amount:
			_animate_win_amount_to(pending)
		elif win_displayed_amount <= 0:
			_set_win_display_amount(float(pending))
	else:
		if win_target_amount > 0 or win_displayed_amount > 0:
			_animate_win_amount_to(0)
		else:
			win_paytable_rank_key = ""
			if win_slot_label != null:
				win_slot_label.text = ""
			if win_amount_label != null:
				win_amount_label.text = ""
			_refresh_paytable_values()
			_refresh_paytable_highlights()

func _animate_win_amount_to(target_amount: int) -> void:
	if paytable_amount_labels.is_empty():
		return
	if win_counter_tween != null and win_counter_tween.is_valid():
		win_counter_tween.kill()
	win_target_amount = max(0, target_amount)
	if win_target_amount > 0 and win_paytable_rank_key.is_empty():
		win_paytable_rank_key = _paytable_rank_key(store.hand_rank())
	var distance: int = abs(win_target_amount - win_displayed_amount)
	var duration: float = clampf(float(distance) / 12000000.0, WIN_COUNTER_MIN_DURATION, WIN_COUNTER_MAX_DURATION)
	win_counter_tween = create_tween()
	win_counter_tween.tween_method(Callable(self, "_set_win_display_amount"), float(win_displayed_amount), float(win_target_amount), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	win_counter_tween.finished.connect(_on_win_counter_finished)
	_pulse_win_display()

func _set_win_display_amount(value: Variant) -> void:
	win_displayed_amount = max(0, int(round(float(value))))
	if win_amount_label != null:
		win_amount_label.text = ""
		if win_displayed_amount > 0:
			win_amount_label.text = "+%s" % _format_amount(win_displayed_amount)
	_refresh_paytable_values()
	_refresh_paytable_highlights()

func _pulse_win_display() -> void:
	var score_label := _active_win_paytable_amount_label()
	if score_label == null:
		return
	if win_pulse_tween != null and win_pulse_tween.is_valid():
		win_pulse_tween.kill()
	score_label.pivot_offset = score_label.size * 0.5
	score_label.scale = Vector2(1.10, 1.10)
	win_pulse_tween = create_tween()
	win_pulse_tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_win_counter_finished() -> void:
	if win_target_amount <= 0 and win_displayed_amount <= 0:
		var score_label := _active_win_paytable_amount_label()
		if score_label != null:
			score_label.scale = Vector2(1.0, 1.0)
		win_paytable_rank_key = ""
		if win_slot_label != null:
			win_slot_label.text = ""
		if win_amount_label != null:
			win_amount_label.text = ""
			win_amount_label.scale = Vector2(1.0, 1.0)
		_refresh_paytable_values()
		_refresh_paytable_highlights()

func _active_win_paytable_amount_label() -> Label:
	var key := win_paytable_rank_key
	if key.is_empty():
		key = _paytable_rank_key(store.hand_rank())
	if key.is_empty() or not paytable_amount_labels.has(key):
		return null
	return paytable_amount_labels.get(key, null) as Label

func _paytable_rank_key(raw_rank: String) -> String:
	var key := raw_rank.strip_edges()
	if paytable_amount_labels.has(key):
		return key
	var normalized := key.replace(" ", "").replace("_", "").replace("-", "").to_lower()
	match normalized:
		"royalflush":
			return "RoyalFlush"
		"straightflush":
			return "StraightFlush"
		"fourofakind", "fourkind":
			return "FourOfAKind"
		"fullhouse":
			return "FullHouse"
		"flush":
			return "Flush"
		"straight":
			return "Straight"
		"threeofakind", "threekind":
			return "ThreeOfAKind"
		"twopair":
			return "TwoPair"
	return ""

func _refresh_lucky5_banner() -> void:
	var du := _double_up_data()
	var is_lucky5 := _du_bool(du, ["is_lucky5_active", "isLucky5Active", "IsLucky5Active", "lucky5", "Lucky5", "winLucky5", "WinLucky5"])
	lucky5_banner.visible = is_lucky5
	lucky5_banner.text = "LUCKY 5 IS ACTIVE" if is_lucky5 else ""

func _refresh_auth_panel() -> void:
	if auth_panel == null: return
	var needs_auth := access_token.is_empty()
	auth_panel.visible = needs_auth
	auth_message_label.text = auth_status
	if otp_edit != null: otp_edit.visible = needs_auth and not pending_signup_username.is_empty()

func _is_action_enabled(id: String) -> bool:
	if id == "menu":
		return true
	if id in ["reconnect_sync", "logout"] and access_token.is_empty():
		return true
	if access_token.is_empty(): return false
	if id in ["reconnect_sync", "logout", "admin_toggle"]:
		return true
	if not _is_connection_live():
		return false
	if _has_pending_command() and id not in ["menu", "reconnect_sync", "logout", "admin_toggle"]: return false
	if id in ["back_to_lobby"]: return true
	if id == "bet" and (_can_switch_double_up_dealer() or _can_start_double_up_from_win()): return true
	if id == "take_score" and store.can_press("cash_out"): return true
	return store.can_press(id)

func _can_switch_double_up_dealer() -> bool:
	if access_token.is_empty() or _has_pending_command() or not store.commands_allowed():
		return false
	if store.current_round_id().is_empty():
		return false
	var du := _double_up_data()
	if not _is_double_up_active(du) or _du_switches_remaining(du) <= 0:
		return false
	return store.can_press("double_up_switch") or _is_double_up_state_name(store.game_state())

func _can_start_double_up_from_win() -> bool:
	if access_token.is_empty() or _has_pending_command() or not store.commands_allowed():
		return false
	var round_id := store.current_round_id()
	if round_id.is_empty():
		return false
	if _is_double_up_active(_double_up_data()):
		return false
	var game_state := store.game_state()
	if not (game_state in ["win", "drawn", "result"]):
		return false
	return _evaluation_double_up_available(_evaluation_data())

func _maybe_auto_start_double_up(game_state: String, du_active: bool) -> void:
	if du_active or not (game_state in ["win", "drawn", "result"]):
		_cancel_auto_double_up_timer()
		return
	if not _can_start_double_up_from_win():
		_cancel_auto_double_up_timer()
		return
	var round_id := store.current_round_id()
	if round_id.is_empty() or auto_double_up_round_ids.has(round_id):
		_cancel_auto_double_up_timer()
		return
	if auto_double_up_pending_round_id == round_id and auto_double_up_timer != null and not auto_double_up_timer.is_stopped():
		return
	auto_double_up_pending_round_id = round_id
	if auto_double_up_timer != null:
		auto_double_up_timer.stop()
		auto_double_up_timer.start()

func _cancel_auto_double_up_timer() -> void:
	auto_double_up_pending_round_id = ""
	if auto_double_up_timer != null:
		auto_double_up_timer.stop()

func _on_auto_double_up_timer_timeout() -> void:
	var round_id := auto_double_up_pending_round_id
	auto_double_up_pending_round_id = ""
	if round_id.is_empty() or auto_double_up_round_ids.has(round_id):
		return
	if not _can_start_double_up_from_win():
		return
	auto_double_up_round_ids.append(round_id)
	_send_command("double_up_start", {"round_id": round_id})

func _is_double_up_state_name(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	normalized = normalized.replace("-", "_").replace(" ", "_")
	return normalized == "double_up" or normalized == "doubleup"

func _double_up_data() -> Dictionary:
	var source: Variant = store.snapshot.get("double_up", null)
	if typeof(source) != TYPE_DICTIONARY:
		source = store.snapshot.get("doubleUp", null)
	if typeof(source) != TYPE_DICTIONARY:
		source = store.snapshot.get("doubleUpSession", null)
	if typeof(source) != TYPE_DICTIONARY:
		var active_round: Variant = store.snapshot.get("activeRound", {})
		if typeof(active_round) == TYPE_DICTIONARY:
			source = active_round.get("double_up", active_round.get("doubleUpSession", null))
	return source if typeof(source) == TYPE_DICTIONARY else {}

func _jackpot_data() -> Dictionary:
	var source: Variant = store.snapshot.get("jackpot", null)
	if typeof(source) != TYPE_DICTIONARY:
		source = store.snapshot.get("jackpots", null)
	return source if typeof(source) == TYPE_DICTIONARY else {}

func _jackpot_active_4k_slot(jp: Dictionary) -> String:
	var raw: Variant = _du_first_value(jp, ["active_four_of_a_kind_slot", "activeFourOfAKindSlot", "ActiveFourOfAKindSlot"], "A")
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		return "B" if store._to_int(raw) == 1 else "A"
	var normalized := str(raw).strip_edges().to_upper()
	if normalized == "1":
		return "B"
	if normalized == "0":
		return "A"
	return "B" if normalized == "B" else "A"

func _evaluation_data() -> Dictionary:
	var source: Variant = store.snapshot.get("evaluation", {})
	return source if typeof(source) == TYPE_DICTIONARY else {}

func _is_double_up_active(du_data: Dictionary) -> bool:
	var active: Variant = _du_first_value(du_data, ["active", "isActive", "Active", "InDoubleUp", "inDoubleUp"], null)
	if typeof(active) == TYPE_BOOL:
		return bool(active)
	if _is_double_up_state_name(store.game_state()):
		return true
	var phase := str(_snapshot_first_value(["phase", "Phase", "gameState", "game_state"], ""))
	if _is_double_up_state_name(phase):
		return true
	var dealer_code := _du_card_code(du_data, ["dealer_card", "dealerCard", "DealerCard", "double_up_card", "doubleUpCard", "DoubleUpCard"])
	if dealer_code.length() < 2:
		return false
	var normalized_status := _du_status(du_data).strip_edges().to_lower()
	return normalized_status.is_empty() or (
		normalized_status.find("lose") < 0
		and normalized_status.find("lost") < 0
		and normalized_status.find("cash") < 0
		and normalized_status.find("complete") < 0
	)

func _evaluation_double_up_available(evaluation: Dictionary) -> bool:
	return _du_bool(evaluation, ["double_up_available", "doubleUpAvailable", "DoubleUpAvailable"])

func _du_switches_remaining(du_data: Dictionary) -> int:
	return store._to_int(_du_first_value(du_data, ["switches_remaining", "switchesRemaining", "SwitchesRemaining", "swap_active_remaining", "swapActiveRemaining", "SwapActiveRemaining"], 0))

func _du_status(du_data: Dictionary) -> String:
	return str(_du_first_value(du_data, ["status", "Status", "outcome", "Outcome"], ""))

func _du_card_code(du_data: Dictionary, keys: Array) -> String:
	return _du_entry_code(_du_first_value(du_data, keys, {}))

func _du_bool(du_data: Dictionary, keys: Array) -> bool:
	var value: Variant = _du_first_value(du_data, keys, false)
	if typeof(value) == TYPE_BOOL:
		return value
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return store._to_int(value) != 0
	if typeof(value) == TYPE_STRING:
		var normalized := str(value).strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes"
	return false

func _du_array(du_data: Dictionary, keys: Array) -> Array:
	var value: Variant = _du_first_value(du_data, keys, [])
	return value if typeof(value) == TYPE_ARRAY else []

func _du_first_value(du_data: Dictionary, keys: Array, fallback: Variant = null) -> Variant:
	for key in keys:
		var name := str(key)
		if du_data.has(name):
			return du_data[name]
	return fallback

func _snapshot_first_value(keys: Array, fallback: Variant = null) -> Variant:
	for key in keys:
		var name := str(key)
		if store.snapshot.has(name):
			return store.snapshot[name]
	return fallback

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
	if index == 0 and _can_switch_full_house_rank():
		_play_press_sound()
		_send_full_house_rank_switch()
		return
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
	_play_press_sound()
	match id:
		"menu":
			menu_open = not menu_open
			_refresh_ui()
		"cash_in":
			cash_in_amount = _sanitize_cash_amount(cash_in_edit.text); cash_in_edit.text = str(cash_in_amount)
			_send_command("cash_in", {"amount": str(cash_in_amount)})
		"cash_out":
			_cancel_auto_double_up_timer()
			_send_command("cash_out", {})
		"deal_draw":
			_cancel_auto_double_up_timer()
			if store.game_state() == "hold":
				var round_id := store.current_round_id()
				if not round_id.is_empty(): _send_command("draw", {"round_id": round_id, "hold_indexes": _draw_hold_indexes()})
			else: _send_command("deal", {"bet_amount": str(selected_bet)})
		"bet":
			if _can_switch_double_up_dealer():
				var switch_round_id := store.current_round_id()
				if not switch_round_id.is_empty(): _send_command("double_up_switch", {"round_id": switch_round_id})
			elif _can_start_double_up_from_win():
				_send_double_up_start()
			else: _cycle_bet()
		"cancel_hold": local_hold_indexes.clear(); auto_holds_cancelled = true; _send_command("clear_holds", {}); _refresh_ui()
		"big": _send_double_up_guess("big")
		"small": _send_double_up_guess("small")
		"swap_double_up_card":
			var switch_round_id := store.current_round_id()
			if not switch_round_id.is_empty(): _send_command("double_up_switch", {"round_id": switch_round_id})
		"take_half":
			_cancel_auto_double_up_timer()
			var round_id := store.current_round_id()
			if not round_id.is_empty(): _send_command("take_half", {"round_id": round_id})
		"take_score":
			_cancel_auto_double_up_timer()
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
	_cancel_auto_double_up_timer()
	var round_id := store.current_round_id()
	if round_id.is_empty(): return
	_send_command("double_up_guess", {"round_id": round_id, "guess": guess})

func _send_double_up_start() -> void:
	_cancel_auto_double_up_timer()
	var round_id := store.current_round_id()
	if round_id.is_empty(): return
	_send_command("double_up_start", {"round_id": round_id})

func _cycle_bet() -> void:
	_cancel_auto_double_up_timer()
	var min_value: int = max(1, store.min_bet()); var max_value: int = max(min_value, store.max_bet()); var step: int = min_value
	selected_bet += step
	if selected_bet > max_value: selected_bet = min_value
	_send_command("bet_change", {"bet_amount": str(selected_bet)}, false); _refresh_ui()

func _can_switch_full_house_rank() -> bool:
	if access_token.is_empty() or _has_pending_command() or not store.commands_allowed():
		return false
	if store.game_state() != "idle":
		return false
	if not store.can_press("hold_0"):
		return false
	if not store.cards().is_empty() or not store.result_cards().is_empty():
		return false
	return true

func _send_full_house_rank_switch() -> void:
	_cancel_auto_double_up_timer()
	_send_command("jackpot_rank_change", {"rank": _next_full_house_rank()})

func _next_full_house_rank() -> int:
	var jp: Dictionary = _jackpot_data()
	var current := store._to_int(_du_first_value(jp, ["full_house_rank", "fullHouseRank", "FullHouseRank"], 0))
	if current < 2 or current >= 14:
		return 2
	return current + 1

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
	_enter_connection_state(ConnectionState.RECOVERY_REQUIRED)
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
