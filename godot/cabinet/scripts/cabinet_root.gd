extends Control

const CabinetStateStoreScript = preload("res://scripts/cabinet_state_store.gd")
const CabinetApiClientScript = preload("res://scripts/cabinet_api_client.gd")
const CabinetControlsScript = preload("res://scripts/cabinet_controls.gd")

var _paytable_rows := [
	{"key": "RoyalFlush", "label": "ROYAL FLUSH", "mult": 1000, "color": Color8(245, 72, 72)},
	{"key": "StraightFlush", "label": "STRAIGHT FLUSH", "mult": 75, "color": Color8(235, 66, 78)},
	{"key": "FourOfAKind", "label": "4 OF A KIND", "mult": 15, "color": Color8(42, 224, 226)},
	{"key": "FullHouse", "label": "FULL HOUSE", "mult": 12, "color": Color8(250, 250, 250)},
	{"key": "Flush", "label": "FLUSH", "mult": 10, "color": Color8(255, 200, 62)},
	{"key": "Straight", "label": "STRAIGHT", "mult": 8, "color": Color8(49, 194, 255)},
	{"key": "ThreeOfAKind", "label": "3 OF A KIND", "mult": 3, "color": Color8(255, 186, 38)},
	{"key": "TwoPair", "label": "2 PAIR", "mult": 2, "color": Color8(49, 208, 255)}
]

var _button_layout := [
	[
		{"id": "hold_0", "label": "HOLD", "color": Color8(250, 206, 55), "text": Color.BLACK},
		{"id": "hold_1", "label": "HOLD", "color": Color8(250, 206, 55), "text": Color.BLACK},
		{"id": "hold_2", "label": "HOLD", "color": Color8(250, 206, 55), "text": Color.BLACK},
		{"id": "hold_3", "label": "HOLD", "color": Color8(250, 206, 55), "text": Color.BLACK},
		{"id": "hold_4", "label": "HOLD", "color": Color8(250, 206, 55), "text": Color.BLACK}
	],
	[
		{"id": "big", "label": "BIG", "color": Color8(245, 151, 32), "text": Color.BLACK},
		{"id": "small", "label": "SMALL", "color": Color8(245, 151, 32), "text": Color.BLACK},
		{"id": "cancel", "label": "CANCEL\nHOLD", "color": Color8(243, 231, 214), "text": Color8(42, 42, 42)},
		{"id": "deal", "label": "DEAL\nDRAW", "color": Color8(236, 54, 42), "text": Color.WHITE},
		{"id": "bet", "label": "BET", "color": Color8(44, 210, 62), "text": Color.BLACK}
	],
	[
		{"id": "take_half", "label": "TAKE\nHALF", "color": Color8(236, 54, 42), "text": Color.WHITE},
		{"id": "menu", "label": "MENU", "color": Color8(38, 35, 33), "text": Color8(220, 220, 220)},
		{"id": "take_score", "label": "TAKE\nSCORE", "color": Color8(245, 168, 42), "text": Color.BLACK}
	]
]

var _store
var _api
var _controls

var _paytable_amounts: Dictionary = {}
var _paytable_panels: Dictionary = {}
var _card_nodes: Array = []
var _button_nodes: Dictionary = {}

var _credits_value: Label
var _stake_value: Label
var _win_value: Label
var _machine_serie: Label
var _machine_kent: Label
var _machine_serial: Label
var _jp_a: Label
var _jp_sf: Label
var _jp_b: Label
var _jp_fh: Label
var _bonus_text: Label
var _message_label: Label
var _idle_overlay: Control

func _ready() -> void:
	custom_minimum_size = Vector2(720, 1280)
	_store = CabinetStateStoreScript.new()
	_api = CabinetApiClientScript.new()
	_controls = CabinetControlsScript.new()
	_controls.command_requested.connect(_on_command_requested)
	_store.snapshot_applied.connect(_render_snapshot)
	_build_scene()
	_store.apply_snapshot(_api.load_classic_snapshot())

func _build_scene() -> void:
	var background := ColorRect.new()
	background.color = Color8(3, 3, 3)
	background.position = Vector2.ZERO
	background.size = Vector2(720, 1280)
	add_child(background)

	var paytable := Panel.new()
	paytable.position = Vector2(16, 14)
	paytable.size = Vector2(400, 236)
	paytable.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT))
	add_child(paytable)

	var paytable_box := VBoxContainer.new()
	paytable_box.position = Vector2.ZERO
	paytable_box.size = paytable.size
	paytable_box.add_theme_constant_override("separation", 4)
	paytable.add_child(paytable_box)

	for row in _paytable_rows:
		var row_panel := Panel.new()
		row_panel.custom_minimum_size = Vector2(paytable.size.x, 24)
		row_panel.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT))
		var line := HBoxContainer.new()
		line.position = Vector2.ZERO
		line.size = Vector2(paytable.size.x, 24)
		line.add_theme_constant_override("separation", 12)
		row_panel.add_child(line)

		var hand_name := _pixel_label(row["label"], 18, row["color"], 1, Color.BLACK)
		hand_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(hand_name)

		var amount := _pixel_label("0", 18, row["color"], 1, Color.BLACK)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(amount)

		paytable_box.add_child(row_panel)
		_paytable_amounts[row["key"]] = amount
		_paytable_panels[row["key"]] = row_panel

	var counters := Panel.new()
	counters.position = Vector2(500, 16)
	counters.size = Vector2(200, 180)
	counters.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT))
	add_child(counters)

	var credits_label := _pixel_label("CREDIT", 18, Color8(80, 220, 115), 1, Color.BLACK)
	credits_label.position = Vector2(24, 0)
	counters.add_child(credits_label)
	_credits_value = _pixel_label("0", 24, Color.WHITE, 2, Color.BLACK)
	_credits_value.position = Vector2(24, 28)
	counters.add_child(_credits_value)

	var stake_label := _pixel_label("STAKE", 18, Color8(255, 185, 56), 1, Color.BLACK)
	stake_label.position = Vector2(56, 90)
	counters.add_child(stake_label)
	_stake_value = _pixel_label("0", 24, Color.WHITE, 2, Color.BLACK)
	_stake_value.position = Vector2(62, 118)
	counters.add_child(_stake_value)

	var card_row := HBoxContainer.new()
	card_row.position = Vector2(20, 250)
	card_row.size = Vector2(680, 240)
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 12)
	add_child(card_row)

	for _i in range(5):
		var card_panel := _create_card_panel()
		card_row.add_child(card_panel["panel"])
		_card_nodes.append(card_panel)

	_win_value = _pixel_label("0", 30, Color8(255, 214, 73), 3, Color8(90, 24, 0))
	_win_value.position = Vector2(220, 510)
	_win_value.size = Vector2(280, 40)
	_win_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_win_value)

	var machine_block := Panel.new()
	machine_block.position = Vector2(8, 572)
	machine_block.size = Vector2(704, 145)
	machine_block.add_theme_stylebox_override("panel", _style_box(Color.TRANSPARENT))
	add_child(machine_block)

	_machine_serie = _pixel_label("SERIE - 0", 16, Color8(75, 211, 95), 1, Color.BLACK)
	_machine_serie.position = Vector2(0, 6)
	machine_block.add_child(_machine_serie)
	_machine_kent = _pixel_label("KENT /3 : 0", 16, Color8(75, 211, 95), 1, Color.BLACK)
	_machine_kent.position = Vector2(0, 32)
	machine_block.add_child(_machine_kent)
	_machine_serial = _pixel_label("S/N: 0", 16, Color8(55, 193, 255), 1, Color.BLACK)
	_machine_serial.position = Vector2(0, 64)
	machine_block.add_child(_machine_serial)

	_jp_a = _pixel_label("0", 20, Color8(60, 240, 110), 1, Color.BLACK)
	_jp_a.position = Vector2(76, 16)
	machine_block.add_child(_jp_a)
	_jp_sf = _pixel_label("0", 20, Color8(255, 72, 72), 1, Color.BLACK)
	_jp_sf.position = Vector2(292, 16)
	machine_block.add_child(_jp_sf)
	_jp_b = _pixel_label("0", 20, Color8(60, 240, 110), 1, Color.BLACK)
	_jp_b.position = Vector2(556, 16)
	machine_block.add_child(_jp_b)
	_jp_fh = _pixel_label("0", 20, Color8(55, 193, 255), 1, Color.BLACK)
	_jp_fh.position = Vector2(76, 52)
	machine_block.add_child(_jp_fh)

	_bonus_text = _pixel_label("4 OF A KIND WINS BONUS", 24, Color.WHITE, 2, Color.BLACK)
	_bonus_text.position = Vector2(30, 94)
	machine_block.add_child(_bonus_text)

	_message_label = _pixel_label("INSERT COIN", 18, Color8(255, 255, 255), 1, Color.BLACK)
	_message_label.position = Vector2(210, 712)
	_message_label.size = Vector2(300, 24)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)

	var controls_panel := Panel.new()
	controls_panel.position = Vector2(8, 760)
	controls_panel.size = Vector2(704, 500)
	controls_panel.add_theme_stylebox_override("panel", _style_box(Color8(66, 31, 10), Color8(48, 19, 5), 4, 4))
	add_child(controls_panel)

	var y_offset := 22.0
	for row in _button_layout:
		var x_offset := 18.0
		var button_width := 0.0
		if row.size() == 5:
			button_width = 118.0
		else:
			button_width = 170.0
			x_offset = 28.0
		for button_def in row:
			var button_height := 118.0 if row.size() == 5 else 126.0
			var button := _create_button(button_def["label"], button_def["color"], button_def["text"], button_width, button_height)
			button.position = Vector2(x_offset, y_offset)
			controls_panel.add_child(button)
			var button_id := String(button_def["id"])
			button.pressed.connect(func(): _controls.emit_command(button_id, {}))
			_button_nodes[button_def["id"]] = button
			x_offset += button_width + 18.0
		y_offset += 154.0 if row.size() == 5 else 166.0

	_idle_overlay = Control.new()
	_idle_overlay.position = Vector2(46, 300)
	_idle_overlay.size = Vector2(628, 180)
	add_child(_idle_overlay)

	var idle_lucky := _pixel_label("LUCKY5", 54, Color8(35, 220, 255), 2, Color8(0, 55, 72))
	idle_lucky.position = Vector2(0, 0)
	idle_lucky.rotation_degrees = -3.0
	_idle_overlay.add_child(idle_lucky)

	var idle_poker := _pixel_label("POKER", 58, Color8(35, 220, 255), 2, Color8(0, 55, 72))
	idle_poker.position = Vector2(204, 74)
	idle_poker.rotation_degrees = -3.0
	_idle_overlay.add_child(idle_poker)
	_idle_overlay.visible = false

func _render_snapshot(snapshot: Dictionary) -> void:
	var bet := _to_float(snapshot.get("credits", {}).get("bet", 0))
	for row in _paytable_rows:
		var key := String(row["key"])
		if _paytable_amounts.has(key):
			_paytable_amounts[key].text = _format_num(int(row["mult"] * bet))
		if _paytable_panels.has(key):
			var is_active: bool = snapshot.get("evaluation", {}).get("hand_rank", "") == key
			var bg := Color8(238, 238, 238, 240) if is_active else Color.TRANSPARENT
			var border := Color8(255, 255, 255) if is_active else Color.TRANSPARENT
			var border_width := 2 if is_active else 0
			_paytable_panels[key].add_theme_stylebox_override("panel", _style_box(bg, border, border_width))

	_credits_value.text = _format_num(int(_to_float(snapshot.get("credits", {}).get("balance", 0))))
	_stake_value.text = _format_num(int(bet))
	_win_value.text = _format_num(int(_to_float(snapshot.get("evaluation", {}).get("win_amount", 0))))

	var jackpot: Dictionary = snapshot.get("jackpot", {})
	var current_values: Dictionary = jackpot.get("current_values", {})
	_machine_serie.text = "SERIE - %s" % jackpot.get("machine_serie", "0")
	_machine_kent.text = "KENT /3 : %s" % jackpot.get("machine_kent", "0")
	_machine_serial.text = "S/N: %s" % jackpot.get("machine_serial", "0")
	_jp_a.text = _format_num(int(_to_float(current_values.get("four_of_a_kind_a", 0))))
	_jp_sf.text = _format_num(int(_to_float(current_values.get("straight_flush", 0))))
	_jp_b.text = _format_num(int(_to_float(current_values.get("four_of_a_kind_b", 0))))
	_jp_fh.text = _format_num(int(_to_float(current_values.get("full_house", 0))))

	var cards: Array = snapshot.get("hand", {}).get("result_cards", [])
	for index in range(min(cards.size(), _card_nodes.size())):
		_render_card(_card_nodes[index], cards[index])

	var enabled: Array = snapshot.get("ui_hints", {}).get("enabled_buttons", [])
	for key in _button_nodes.keys():
		_button_nodes[key].disabled = not enabled.has(key)

	_message_label.text = String(snapshot.get("ui_hints", {}).get("message", "READY"))
	_bonus_text.text = String(snapshot.get("ui_hints", {}).get("bonus_message", ""))
	_idle_overlay.visible = bool(snapshot.get("ui_hints", {}).get("idle_title_visible", false))

func _render_card(card_node: Dictionary, card: Dictionary) -> void:
	var suit := String(card.get("suit", ""))
	var is_red := suit == "H" or suit == "D"
	var suit_symbol: String = {"S": "S", "H": "H", "D": "D", "C": "C"}.get(suit, "?")
	var color := Color8(220, 40, 40) if is_red else Color8(20, 20, 20)
	card_node["rank_top"].text = String(card.get("rank", ""))
	card_node["rank_top"].modulate = color
	card_node["rank_bottom"].text = String(card.get("rank", ""))
	card_node["rank_bottom"].modulate = color
	card_node["suit"].text = suit_symbol
	card_node["suit"].modulate = color

func _on_command_requested(command_type: String, payload: Dictionary) -> void:
	var snapshot: Dictionary = _store.snapshot
	var command: Dictionary = _api.emit_command(
		command_type,
		int(snapshot.get("machine_id", 1)),
		snapshot.get("session_id", null),
		int(snapshot.get("state_version", 0)),
		payload
	)
	_message_label.text = "CMD %s" % String(command.get("command_type", "")).to_upper()

func _create_card_panel() -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(120, 172)
	panel.size = Vector2(120, 172)
	panel.add_theme_stylebox_override("panel", _style_box(Color.WHITE, Color8(205, 205, 205), 2, 8))

	var rank_top := _pixel_label("A", 24, Color.BLACK, 0)
	rank_top.position = Vector2(10, 6)
	panel.add_child(rank_top)

	var suit_label := _pixel_label("S", 56, Color.BLACK, 0)
	suit_label.position = Vector2(36, 48)
	panel.add_child(suit_label)

	var rank_bottom := _pixel_label("A", 24, Color.BLACK, 0)
	rank_bottom.position = Vector2(82, 132)
	rank_bottom.rotation_degrees = 180.0
	panel.add_child(rank_bottom)

	return {
		"panel": panel,
		"rank_top": rank_top,
		"rank_bottom": rank_bottom,
		"suit": suit_label
	}

func _create_button(text: String, bg: Color, fg: Color, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.size = Vector2(width, height)
	button.custom_minimum_size = button.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _button_style(bg))
	button.add_theme_stylebox_override("hover", _button_style(bg.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _button_style(bg.darkened(0.12)))
	button.add_theme_stylebox_override("disabled", _button_style(bg.darkened(0.32)))
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_color_override("font_pressed_color", fg)
	button.add_theme_color_override("font_disabled_color", fg.darkened(0.35))
	button.add_theme_font_size_override("font_size", 46 if text == "MENU" else 24)
	return button

func _pixel_label(text: String, font_size: int, color: Color, outline_size: int, outline_color: Color = Color.BLACK) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = outline_size
	settings.outline_color = outline_color
	label.label_settings = settings
	return label

func _button_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 12
	style.border_color = bg.darkened(0.38)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 6)
	return style

func _style_box(fill: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	return style

func _format_num(value: int) -> String:
	var digits := str(abs(value))
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	groups.push_front(digits)
	var result := ",".join(groups)
	return "-%s" % result if value < 0 else result

func _to_float(value) -> float:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return float(value)
		TYPE_STRING:
			return String(value).to_float()
		_:
			return 0.0
