extends Control
## Lobby — Apple HIG: large title, grouped cards, room discovery via LanDiscovery + RoomManager.

const Registry = preload("res://autoload/GameRegistry.gd")

@onready var _app_state: Node = get_node("/root/AppState")
@onready var _game_registry: Node = get_node("/root/GameRegistry")
@onready var _lan_discovery: Node = get_node("/root/LanDiscovery")
@onready var _room_manager: Node = get_node("/root/RoomManager")

var _selected_id: String = "xiangqi"
var _in_room: bool = false

@onready var _grid: GridContainer = %GameGrid
@onready var _hint: Label = %Hint
@onready var _online_dialog: AcceptDialog = %OnlineDialog
@onready var _name_input: LineEdit = %NameInput
@onready var _lan_section: VBoxContainer = %LanSection
@onready var _rooms_empty: Label = %RoomsEmpty
@onready var _rooms_list: VBoxContainer = %RoomsList
@onready var _room_code_input: LineEdit = %RoomCodeInput
@onready var _direct_ip_input: LineEdit = %DirectIPInput
@onready var _room_info: Panel = %RoomInfoCard
@onready var _room_code_label: Label = %RoomCodeLabel
@onready var _room_sub: Label = %RoomSub

func _ready() -> void:
	_apply_apple_chrome()
	_build_grid()
	_update_hint()
	_wire_lobby()
	_wire_rooms()
	# Restore name
	_name_input.text = str(_app_state.get("player_name"))
	_name_input.text_changed.connect(func(t: String) -> void: _app_state.set("player_name", t.strip_edges()))

func _apply_apple_chrome() -> void:
	var header: Panel = get_node("Center/Scroll/Content/HeaderCard")
	var modes: Panel = get_node("Center/Scroll/Content/ModesCard")
	var rooms_card: Panel = get_node("Center/Scroll/Content/LanSection/RoomsCard")
	AppleStyle.apply_card(header)
	AppleStyle.apply_card(modes)
	AppleStyle.apply_card(rooms_card)
	AppleStyle.apply_card(_room_info)
	AppleStyle.apply_primary_button(%BtnAI)
	AppleStyle.apply_primary_button(%BtnCreateRoom)
	AppleStyle.apply_secondary_button(%BtnBrowseRooms)
	AppleStyle.apply_secondary_button(%BtnOnline)
	%BtnOnline.modulate = Color(1, 1, 1, 0.62)
	AppleStyle.apply_primary_button(%BtnJoinCode)
	AppleStyle.apply_secondary_button(%BtnDirectJoin)
	AppleStyle.apply_primary_button(%BtnStartGame)
	AppleStyle.apply_secondary_button(%BtnLeaveRoom)

func _wire_lobby() -> void:
	%BtnAI.pressed.connect(_on_ai)
	%BtnCreateRoom.pressed.connect(_on_create_room)
	%BtnBrowseRooms.pressed.connect(_on_browse_rooms)
	%BtnOnline.pressed.connect(func() -> void: _online_dialog.popup_centered())

func _wire_rooms() -> void:
	%BtnJoinCode.pressed.connect(_on_join_code)
	%BtnDirectJoin.pressed.connect(_on_direct_join)
	%BtnStartGame.pressed.connect(_on_start_game)
	%BtnLeaveRoom.pressed.connect(_on_leave_room)
	_room_code_input.text_submitted.connect(func(_t: String) -> void: _on_join_code())
	_direct_ip_input.text_submitted.connect(func(_t: String) -> void: _on_direct_join())
	_lan_discovery.rooms_updated.connect(_on_rooms_updated)
	_lan_discovery.peer_found.connect(func(_info: Dictionary) -> void: _refresh_rooms())
	_lan_discovery.peer_lost.connect(func(_ip: String) -> void: _refresh_rooms())
	_room_manager.room_created.connect(_on_room_created)
	_room_manager.room_joined.connect(_on_room_joined)
	_room_manager.room_error.connect(func(msg: String) -> void: _hint.text = msg)
	_room_manager.room_peer_joined.connect(func(_id: int) -> void: _room_sub.text = "对手已加入 — 点击开始游戏。")
	_room_manager.room_peer_left.connect(func(_id: int) -> void: _room_sub.text = "对手已离开。")

# -- Game grid --

func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var games: Array = _game_registry.call("get_available_games")
	for id in Registry.GAMES.keys():
		var entry: Dictionary = Registry.GAMES[id]
		if entry.get("status", "") != "available" and not games.any(func(g: Dictionary) -> bool: return g.get("id", "") == id):
			var copy: Dictionary = entry.duplicate()
			copy["id"] = id
			games.append(copy)
	for g in games:
		var card := Panel.new()
		card.custom_minimum_size = Vector2(208, 128)
		AppleStyle.apply_card(card)
		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 6)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(vbox)
		var available: bool = g.get("status", "") == "available"
		var is_selected: bool = available and g["id"] == _selected_id
		if is_selected:
			var sel := StyleBoxFlat.new()
			sel.bg_color = Color.WHITE
			sel.corner_radius_top_left = 16; sel.corner_radius_top_right = 16
			sel.corner_radius_bottom_right = 16; sel.corner_radius_bottom_left = 16
			sel.border_color = ApplePalette.BLUE
			sel.border_width_left = 2; sel.border_width_top = 2; sel.border_width_right = 2; sel.border_width_bottom = 2
			sel.shadow_color = Color("#007AFF", 0.14); sel.shadow_size = 14
			sel.content_margin_left = 16; sel.content_margin_top = 16; sel.content_margin_right = 16; sel.content_margin_bottom = 16
			card.add_theme_stylebox_override("panel", sel)
		if not available:
			card.modulate = Color(1, 1, 1, 0.62)
		var icon_box := Panel.new()
		icon_box.custom_minimum_size = Vector2(48, 48)
		icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var icon_sb := StyleBoxFlat.new()
		icon_sb.bg_color = ApplePalette.BLUE if available else ApplePalette.GRAY_FILL
		icon_sb.corner_radius_top_left = 12; icon_sb.corner_radius_top_right = 12
		icon_sb.corner_radius_bottom_right = 12; icon_sb.corner_radius_bottom_left = 12
		icon_box.add_theme_stylebox_override("panel", icon_sb)
		var glyph := Label.new()
		glyph.text = _glyph_for(g["id"])
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.add_theme_font_size_override("font_size", 22)
		glyph.add_theme_color_override("font_color", Color.WHITE)
		icon_box.add_child(glyph)
		vbox.add_child(icon_box)
		var title := Label.new()
		title.text = g.get("name", g["id"])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", ApplePalette.LABEL if available else ApplePalette.LABEL_TERTIARY)
		vbox.add_child(title)
		var sub := Label.new()
		sub.text = "可用" if available else "敬请期待"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", ApplePalette.GREEN if available else ApplePalette.LABEL_TERTIARY)
		vbox.add_child(sub)
		if available:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.gui_input.connect(_on_card_input.bind(g["id"]))
		_grid.add_child(card)

func _glyph_for(id: String) -> String:
	match id:
		"xiangqi": return "XQ"
		_: return id.substr(0, 2).to_upper()

func _on_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_id = id
		_build_grid()
		_update_hint()
		accept_event()

func _update_hint() -> void:
	var g: Dictionary = _game_registry.call("get_game", _selected_id)
	_hint.text = g.get("description", "")

func _enter_game() -> void:
	var g: Dictionary = _game_registry.call("get_game", _selected_id)
	var scene: String = g.get("scene", "")
	if scene == "" or not bool(_game_registry.call("is_available", _selected_id)):
		return
	_app_state.set("selected_game", _selected_id)
	get_tree().change_scene_to_file(scene)

# -- Single-player --

func _on_ai() -> void:
	_app_state.call("set_mode", 1) # AppState.Mode.AI
	_enter_game()

# -- Rooms --

func _on_create_room() -> void:
	var code: String = _room_manager.create_room(_selected_id)
	if code == "":
		return
	_in_room = true
	_room_code_label.text = code
	_room_sub.text = "将此房间码分享给同一WiFi下的好友"
	_room_info.visible = true
	_lan_section.visible = true
	_hint.text = "Room %s created. Waiting for opponent…" % code

func _on_browse_rooms() -> void:
	_lan_section.visible = not _lan_section.visible
	if _lan_section.visible:
		_lan_discovery.start_listening()
		_refresh_rooms()
	else:
		if not _in_room:
			_lan_discovery.stop()

func _on_rooms_updated(_rooms: Array) -> void:
	_refresh_rooms()

func _refresh_rooms() -> void:
	for c in _rooms_list.get_children():
		c.queue_free()
	var rooms: Array = _lan_discovery.get_rooms()
	# Filter by selected game
	var filtered: Array = rooms.filter(func(r: Dictionary) -> bool: return r.get("game_id", "xiangqi") == _selected_id)
	_rooms_empty.visible = filtered.is_empty()
	for r in filtered:
		var row := _make_room_row(r)
		_rooms_list.add_child(row)

func _make_room_row(info: Dictionary) -> Control:
	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.corner_radius_top_left = 10; sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10; sb.corner_radius_bottom_left = 10
	sb.border_color = ApplePalette.SEPARATOR; sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.content_margin_left = 10; sb.content_margin_top = 8; sb.content_margin_right = 10; sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(hbox)
	var code_lbl := Label.new()
	code_lbl.text = info.get("room_code", "--")
	code_lbl.add_theme_font_size_override("font_size", 17)
	code_lbl.add_theme_color_override("font_color", ApplePalette.LABEL)
	hbox.add_child(code_lbl)
	var sep := Label.new()
	sep.text = "·"
	sep.add_theme_color_override("font_color", ApplePalette.LABEL_TERTIARY)
	hbox.add_child(sep)
	var host_lbl := Label.new()
	host_lbl.text = info.get("host_name", "Host")
	host_lbl.add_theme_font_size_override("font_size", 13)
	host_lbl.add_theme_color_override("font_color", ApplePalette.LABEL_SECONDARY)
	host_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(host_lbl)
	var btn := Button.new()
	btn.text = "Join"
	btn.custom_minimum_size = Vector2(72, 32)
	AppleStyle.apply_primary_button(btn)
	btn.pressed.connect(_on_join_discovered.bind(info))
	hbox.add_child(btn)
	card.custom_minimum_size = Vector2(0, 48)
	return card

func _on_join_discovered(info: Dictionary) -> void:
	var err: Error = _room_manager.join_room_at(info["ip"], int(info["port"]), info["room_code"])
	if err != OK:
		return
	_on_room_joined(info["room_code"])

func _on_join_code() -> void:
	var code: String = _room_code_input.text.strip_edges().to_upper()
	if code == "":
		_hint.text = "请输入房间码。"
		return
	var already_discovered: bool = not _lan_discovery.find_room_by_code(code).is_empty()
	var err: Error = _room_manager.join_room_by_code(code)
	if err != OK:
		return
	if not already_discovered:
		_hint.text = "正在加入 %s…" % code
		return
	_on_room_joined(code)

func _on_direct_join() -> void:
	var ip: String = _direct_ip_input.text.strip_edges()
	if ip == "":
		_hint.text = "请输入IP地址。"
		return
	var port: int = 7777
	if ip.contains(":"):
		var parts: PackedStringArray = ip.split(":")
		ip = parts[0]
		port = int(parts[1])
	var err: Error = _room_manager.join_direct(ip, port)
	if err != OK:
		return
	_on_room_joined("%s:%d" % [ip, port])

func _on_room_created(code: String, _port: int) -> void:
	_in_room = true
	_room_code_label.text = code
	_room_info.visible = true
	_lan_section.visible = true

func _on_room_joined(code: String) -> void:
	_in_room = true
	_room_code_label.text = code
	_room_sub.text = "已加入房间 %s — 点击开始游戏。" % code
	_room_info.visible = true
	%BtnStartGame.text = "Start Game"

func _on_leave_room() -> void:
	_room_manager.leave_room()
	_in_room = false
	_room_info.visible = false
	_hint.text = "已离开房间。"
	# Keep browsing if section was open
	if _lan_section.visible:
		_lan_discovery.start_listening()

func _on_start_game() -> void:
	_enter_game()
