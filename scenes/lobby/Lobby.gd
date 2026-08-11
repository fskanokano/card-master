extends Control
## Lobby — 真·手游化大厅：竖屏全宽、超大字体按钮、全面屏吃满、精简信息、全量音效

const Registry = preload("res://autoload/GameRegistry.gd")

@onready var _app_state: Node = get_node("/root/AppState")
@onready var _game_registry: Node = get_node("/root/GameRegistry")
@onready var _lan_discovery: Node = get_node("/root/LanDiscovery")
@onready var _room_manager: Node = get_node("/root/RoomManager")

var _selected_id: String = "xiangqi"
var _in_room: bool = false
var _card_nodes: Dictionary = {}

@onready var _grid: GridContainer = %GameGrid
@onready var _hint: Label = %Hint
@onready var _online_dialog: AcceptDialog = %OnlineDialog
@onready var _name_input: LineEdit = %NameInput
@onready var _lan_section: VBoxContainer = %LanSection
@onready var _rooms_empty: Panel = %RoomsEmpty
@onready var _rooms_list: VBoxContainer = %RoomsList
@onready var _room_code_input: LineEdit = %RoomCodeInput
@onready var _direct_ip_input: LineEdit = %DirectIPInput
@onready var _room_info: Panel = %RoomInfoCard
@onready var _room_code_label: Label = %RoomCodeLabel
@onready var _room_sub: Label = %RoomSub
@onready var _btn_ai: Button = %BtnAI
@onready var _btn_create: Button = %BtnCreateRoom
@onready var _btn_browse: Button = %BtnBrowseRooms
@onready var _btn_online: Button = %BtnOnline

func _ready() -> void:
	_apply_shell()
	_build_grid()
	_wire_all()
	_restore_name()
	_update_hint()
	_draw_hero_board_preview()
	_apply_immersive_insets()
	_update_responsive()
	_animate_entrance()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_apply_immersive_insets()
	_update_responsive()

func _sfx(key: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	match key:
		"tap": if am.has_method("play_tap"): am.call("play_tap")
		"select": if am.has_method("play_select"): am.call("play_select")
		"invalid": if am.has_method("play_invalid"): am.call("play_invalid")

func _apply_immersive_insets() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x < 10:
		vp_size = Vector2(720, 1280)
	var safe := DisplayServer.get_display_safe_area()
	var win_size := DisplayServer.window_get_size()
	var inset_top: int = 0
	var inset_bottom: int = 0
	var inset_left: int = 0
	var inset_right: int = 0
	if safe.size.y > 0 and safe.position.y > 0:
		inset_top = int(safe.position.y)
		inset_bottom = int(win_size.y - (safe.position.y + safe.size.y))
	if safe.size.x > 0 and safe.position.x > 0:
		inset_left = int(safe.position.x)
		inset_right = int(win_size.x - (safe.position.x + safe.size.x))
	var is_mobile: bool = vp_size.x < 780 or OS.has_feature("mobile") or DisplayServer.get_name() in ["Android", "iOS"]
	if inset_top == 0 and is_mobile:
		inset_top = 30
		inset_bottom = 22
	var top_nav: Panel = get_node_or_null("TopNav") as Panel
	if top_nav != null:
		top_nav.offset_top = inset_top
		top_nav.offset_bottom = inset_top + 72
		top_nav.offset_left = inset_left
		top_nav.offset_right = -inset_right
	var scroll: ScrollContainer = get_node_or_null("MainScroll") as ScrollContainer
	if scroll != null:
		scroll.offset_top = inset_top + 72
		scroll.offset_bottom = -inset_bottom
		scroll.offset_left = inset_left
		scroll.offset_right = -inset_right

func _update_responsive() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10:
		vp = Vector2(720, 1280)
	var is_mobile: bool = vp.x < 780
	var is_tablet: bool = vp.x >= 780 and vp.x < 1024
	var safe := DisplayServer.get_display_safe_area()
	var h_inset: int = 0
	if safe.size.x > 0:
		h_inset = int(safe.position.x) + int(DisplayServer.window_get_size().x - (safe.position.x + safe.size.x))
	var content: VBoxContainer = get_node_or_null("MainScroll/CenterWrap/Content") as VBoxContainer
	if content != null:
		if is_mobile:
			content.custom_minimum_size.x = max(340, vp.x - 20 - h_inset)
			content.add_theme_constant_override("separation", 20)
		elif is_tablet:
			content.custom_minimum_size.x = min(720, vp.x - 28 - h_inset)
		else:
			content.custom_minimum_size.x = 720
			content.add_theme_constant_override("separation", 22)
	# 网格：手机始终 1 列，卡片全宽超大
	if _grid != null:
		_grid.columns = 1 if is_mobile else (2 if is_tablet else 1)
	# 标题：手机端更大
	var title: Label = get_node_or_null("MainScroll/CenterWrap/Content/HeroCard/HeroInner/HeroLeft/HeroTitle") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", 38 if is_mobile else 44)
		title.add_theme_color_override("font_color", ApplePalette.LABEL)
	# TopNav 手机：隐藏 Badge 文字的中文，只留点；名字输入压缩
	var badge: Control = get_node_or_null("TopNav/NavInner/NavBadge") as Control
	var name_wrap: Control = get_node_or_null("TopNav/NavInner/NameWrap") as Control
	var logo_text: Control = get_node_or_null("TopNav/NavInner/LogoText") as Control
	if badge != null:
		badge.visible = vp.x > 360
	if name_wrap != null:
		name_wrap.custom_minimum_size.x = 132 if is_mobile else 180
	if logo_text != null:
		logo_text.visible = vp.x > 340
	_build_grid()

# ── Shell styling ─────────────────────────────────────────
func _apply_shell() -> void:
	var top_nav: Panel = get_node("TopNav")
	var nav_sb := StyleBoxFlat.new()
	nav_sb.bg_color = Color("#141A14", 0.98)
	nav_sb.corner_radius_top_left = 0; nav_sb.corner_radius_top_right = 0
	nav_sb.corner_radius_bottom_right = 0; nav_sb.corner_radius_bottom_left = 0
	nav_sb.border_color = ApplePalette.SEPARATOR; nav_sb.border_width_bottom = 1
	nav_sb.content_margin_left = 14; nav_sb.content_margin_top = 10; nav_sb.content_margin_right = 14; nav_sb.content_margin_bottom = 10
	top_nav.add_theme_stylebox_override("panel", nav_sb)
	var logo_mark: Panel = get_node("TopNav/NavInner/LogoMark")
	var lm := StyleBoxFlat.new()
	lm.bg_color = ApplePalette.GOLD
	lm.corner_radius_top_left = 12; lm.corner_radius_top_right = 12; lm.corner_radius_bottom_right = 12; lm.corner_radius_bottom_left = 12
	logo_mark.add_theme_stylebox_override("panel", lm)
	var name_wrap_p: Panel = get_node("TopNav/NavInner/NameWrap")
	var nw := StyleBoxFlat.new()
	nw.bg_color = Color("#141A14")
	nw.corner_radius_top_left = 12; nw.corner_radius_top_right = 12; nw.corner_radius_bottom_right = 12; nw.corner_radius_bottom_left = 12
	nw.border_color = ApplePalette.SEPARATOR; nw.border_width_left = 1; nw.border_width_top = 1; nw.border_width_right = 1; nw.border_width_bottom = 1
	nw.content_margin_left = 12; nw.content_margin_top = 6; nw.content_margin_right = 12; nw.content_margin_bottom = 6
	name_wrap_p.add_theme_stylebox_override("panel", nw)
	var badge: Panel = get_node("TopNav/NavInner/NavBadge")
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#0E1A15")
	bs.corner_radius_top_left = 20; bs.corner_radius_top_right = 20; bs.corner_radius_bottom_right = 20; bs.corner_radius_bottom_left = 20
	bs.border_color = Color("#2EC4B6", 0.22); bs.border_width_left = 1; bs.border_width_top = 1; bs.border_width_right = 1; bs.border_width_bottom = 1
	bs.content_margin_left = 10; bs.content_margin_top = 4; bs.content_margin_right = 10; bs.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", bs)
	AppleStyle.apply_input(_name_input)
	AppleStyle.apply_input(_room_code_input)
	AppleStyle.apply_input(_direct_ip_input)
	# 输入框更大更易点
	for f in [_name_input, _room_code_input, _direct_ip_input]:
		f.add_theme_font_size_override("font_size", 15)
		f.custom_minimum_size.y = 52 if f != _name_input else 36
	AppleStyle.apply_hero(get_node("MainScroll/CenterWrap/Content/HeroCard"))
	var hero_right: Panel = get_node("MainScroll/CenterWrap/Content/HeroCard/HeroInner/HeroRight")
	var hr := StyleBoxFlat.new()
	hr.bg_color = Color("#141A14")
	hr.corner_radius_top_left = 16; hr.corner_radius_top_right = 16; hr.corner_radius_bottom_right = 16; hr.corner_radius_bottom_left = 16
	hr.border_color = ApplePalette.HAIRLINE_GOLD; hr.border_width_left = 1; hr.border_width_top = 1; hr.border_width_right = 1; hr.border_width_bottom = 1
	hr.shadow_color = ApplePalette.SHADOW_SOFT; hr.shadow_size = 14
	hr.content_margin_left = 14; hr.content_margin_top = 14; hr.content_margin_right = 14; hr.content_margin_bottom = 14
	hero_right.add_theme_stylebox_override("panel", hr)
	AppleStyle.apply_glass(get_node("MainScroll/CenterWrap/Content/ModesCard"))
	AppleStyle.apply_glass(get_node("MainScroll/CenterWrap/Content/LanSection/RoomsCard"))
	AppleStyle.apply_glass(_room_info)
	var empty: Panel = get_node("MainScroll/CenterWrap/Content/LanSection/RoomsCard/RoomsInner/RoomsEmpty")
	var es := StyleBoxFlat.new()
	es.bg_color = Color("#141A14")
	es.corner_radius_top_left = 14; es.corner_radius_top_right = 14; es.corner_radius_bottom_right = 14; es.corner_radius_bottom_left = 14
	es.border_color = ApplePalette.SEPARATOR; es.border_width_left = 1; es.border_width_top = 1; es.border_width_right = 1; es.border_width_bottom = 1
	es.content_margin_left = 16; es.content_margin_top = 18; es.content_margin_right = 16; es.content_margin_bottom = 18
	empty.add_theme_stylebox_override("panel", es)
	var room_badge: Panel = get_node("MainScroll/CenterWrap/Content/LanSection/RoomInfoCard/RoomInfoInner/RoomInfoHeader/RoomBadge")
	var rb := StyleBoxFlat.new()
	rb.bg_color = Color("#1A1208")
	rb.corner_radius_top_left = 8; rb.corner_radius_top_right = 8; rb.corner_radius_bottom_right = 8; rb.corner_radius_bottom_left = 8
	rb.border_color = ApplePalette.HAIRLINE_GOLD; rb.border_width_left = 1; rb.border_width_top = 1; rb.border_width_right = 1; rb.border_width_bottom = 1
	rb.content_margin_left = 8; rb.content_margin_top = 4; rb.content_margin_right = 8; rb.content_margin_bottom = 4
	room_badge.add_theme_stylebox_override("panel", rb)
	# 主按钮超大
	AppleStyle.apply_primary_button(_btn_ai)
	_btn_ai.add_theme_font_size_override("font_size", 18)
	_btn_ai.custom_minimum_size = Vector2(0, 56)
	AppleStyle.apply_secondary_button(_btn_create)
	_btn_create.add_theme_font_size_override("font_size", 15)
	AppleStyle.apply_secondary_button(_btn_browse)
	_btn_browse.add_theme_font_size_override("font_size", 15)
	AppleStyle.apply_secondary_button(_btn_online)
	_btn_online.add_theme_font_size_override("font_size", 15)
	AppleStyle.apply_primary_button(%BtnJoinCode)
	%BtnJoinCode.add_theme_font_size_override("font_size", 15)
	AppleStyle.apply_secondary_button(%BtnDirectJoin)
	%BtnDirectJoin.add_theme_font_size_override("font_size", 15)
	AppleStyle.apply_primary_button(%BtnStartGame)
	%BtnStartGame.add_theme_font_size_override("font_size", 16)
	AppleStyle.apply_secondary_button(%BtnLeaveRoom)
	%BtnLeaveRoom.add_theme_font_size_override("font_size", 15)
	for p in get_node("MainScroll/CenterWrap/Content/ModesCard/ModeRow").get_children():
		if p is Button:
			if p.text == "人机对战":
				AppleStyle.apply_primary_button(p)
			else:
				AppleStyle.apply_secondary_button(p)
			p.add_theme_font_size_override("font_size", 14)
			if p.text == "人机对战":
				p.pressed.connect(_on_ai)
			elif p.text == "创建房间":
				p.pressed.connect(_on_create_room)
			elif p.text == "浏览房间":
				p.pressed.connect(_on_browse_rooms)
			elif p.text == "在线对战":
				p.pressed.connect(func() -> void: _online_dialog.popup_centered(); _sfx("tap"))

func _restore_name() -> void:
	var cur: String = str(_app_state.get("player_name"))
	if cur == "" or cur == "Player":
		_name_input.placeholder_text = "例如  云深"
	else:
		_name_input.text = cur
	_name_input.text_changed.connect(func(t: String) -> void: _app_state.set("player_name", t.strip_edges()))
	_name_input.text_submitted.connect(func(_t: String) -> void: _name_input.release_focus())

func _wire_all() -> void:
	_btn_ai.pressed.connect(_on_ai)
	_btn_create.pressed.connect(_on_create_room)
	_btn_browse.pressed.connect(_on_browse_rooms)
	_btn_online.pressed.connect(func() -> void: _online_dialog.popup_centered(); _sfx("tap"))
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
	_room_manager.room_error.connect(func(msg: String) -> void: _set_hint(msg, true); _sfx("invalid"))
	_room_manager.room_peer_joined.connect(func(_id: int) -> void: _room_sub.text = "对手已加入  ·  点击开始对局"; _sfx("select"))
	_room_manager.room_peer_left.connect(func(_id: int) -> void: _room_sub.text = "对手已离开")
	_room_code_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_room_code_label.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var code: String = _room_code_label.text.strip_edges()
			if code != "" and code != "——  ——  ——" and code != "------":
				DisplayServer.clipboard_set(code)
				_set_hint("已复制房间码 %s" % code, false)
				_sfx("select")
	)

func _animate_entrance() -> void:
	var hero: Control = get_node("MainScroll/CenterWrap/Content/HeroCard")
	var grid: Control = get_node("MainScroll/CenterWrap/Content/GameGrid")
	var modes: Control = get_node("MainScroll/CenterWrap/Content/ModesCard")
	for n in [hero, grid, modes]:
		n.modulate.a = 0.0
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(n, "modulate:a", 1.0, 0.42)
		tw.parallel().tween_property(n, "position:y", n.position.y, 0.42).from(n.position.y + 12)
		await get_tree().create_timer(0.07).timeout

func _draw_hero_board_preview() -> void:
	var host: Control = get_node("MainScroll/CenterWrap/Content/HeroCard/HeroInner/HeroRight/HeroBoardPreview")
	if host.get_child_count() > 0:
		return
	var preview := _HeroBoardPreview.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(preview)

func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_card_nodes.clear()
	var games: Array = _game_registry.call("get_available_games")
	for id in Registry.GAMES.keys():
		var entry: Dictionary = Registry.GAMES[id]
		if entry.get("status", "") != "available" and not games.any(func(g: Dictionary) -> bool: return g.get("id", "") == id):
			var copy2: Dictionary = entry.duplicate()
			copy2["id"] = id
			games.append(copy2)
	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av_a: bool = a.get("status", "") == "available"
		var av_b: bool = b.get("status", "") == "available"
		if av_a != av_b:
			return av_a
		return str(a.get("name", "")) < str(b.get("name", "")))
	for g in games:
		var id: String = g.get("id", "")
		var card := _make_game_card(g)
		_grid.add_child(card)
		_card_nodes[id] = card
	_update_selection_visuals()

func _make_game_card(g: Dictionary) -> Control:
	var id: String = g.get("id", "")
	var available: bool = g.get("status", "") == "available"
	var card := Panel.new()
	var vp: Vector2 = get_viewport_rect().size
	var is_mobile: bool = vp.x < 780 or OS.has_feature("mobile") or DisplayServer.get_name() in ["Android", "iOS"]
	var card_h: float = 220 if is_mobile else 240
	card.custom_minimum_size = Vector2(0, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	if available and id == _selected_id:
		sb.bg_color = Color("#1A1F18")
		sb.corner_radius_top_left = 20; sb.corner_radius_top_right = 20; sb.corner_radius_bottom_right = 20; sb.corner_radius_bottom_left = 20
		sb.border_color = ApplePalette.GOLD; sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
		sb.shadow_color = ApplePalette.GLOW_GOLD; sb.shadow_size = 20
	else:
		sb.bg_color = Color("#151A14")
		sb.corner_radius_top_left = 20; sb.corner_radius_top_right = 20; sb.corner_radius_bottom_right = 20; sb.corner_radius_bottom_left = 20
		sb.border_color = ApplePalette.SEPARATOR; sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
		sb.shadow_color = ApplePalette.SHADOW_SOFT; sb.shadow_size = 12
	sb.content_margin_left = 0; sb.content_margin_top = 0; sb.content_margin_right = 0; sb.content_margin_bottom = 0
	card.add_theme_stylebox_override("panel", sb)
	var root_v := VBoxContainer.new()
	root_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_v.add_theme_constant_override("separation", 0)
	card.add_child(root_v)
	var cover := Panel.new()
	cover.custom_minimum_size = Vector2(0, 112 if is_mobile else 128)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover_sb := StyleBoxFlat.new()
	match id:
		"xiangqi": cover_sb.bg_color = Color("#2B1E12")
		"chess_placeholder": cover_sb.bg_color = Color("#1A2A26")
		"go_placeholder": cover_sb.bg_color = Color("#241E1A")
		_: cover_sb.bg_color = Color("#141E2E")
	cover_sb.corner_radius_top_left = 20; cover_sb.corner_radius_top_right = 20; cover_sb.corner_radius_bottom_right = 0; cover_sb.corner_radius_bottom_left = 0
	cover_sb.content_margin_left = 18; cover_sb.content_margin_top = 16; cover_sb.content_margin_right = 18; cover_sb.content_margin_bottom = 16
	cover.add_theme_stylebox_override("panel", cover_sb)
	root_v.add_child(cover)
	var cover_inner := Control.new()
	cover_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(cover_inner)
	var cover_art := _CoverArt.new()
	cover_art.game_id = id
	cover_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_inner.add_child(cover_art)
	var badge_row := HBoxContainer.new()
	badge_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	badge_row.offset_left = 14; badge_row.offset_top = 12; badge_row.offset_right = -14; badge_row.offset_bottom = 36
	badge_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_inner.add_child(badge_row)
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(0, 24)
	var badge_sb := StyleBoxFlat.new()
	if available:
		badge_sb.bg_color = Color("#C8A46A")
	else:
		badge_sb.bg_color = Color("#1E2937")
	badge_sb.corner_radius_top_left = 20; badge_sb.corner_radius_top_right = 20; badge_sb.corner_radius_bottom_right = 20; badge_sb.corner_radius_bottom_left = 20
	badge_sb.content_margin_left = 12; badge_sb.content_margin_top = 4; badge_sb.content_margin_right = 12; badge_sb.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", badge_sb)
	badge_row.add_child(badge)
	var badge_lbl := Label.new()
	badge_lbl.text = "可对局" if available else "即将上线"
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", Color("#1A1208") if available else Color("#6B7585"))
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.add_child(badge_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_child(spacer)
	if available and id == _selected_id:
		var check := Label.new()
		check.text = "✓  已选"
		check.add_theme_font_size_override("font_size", 12)
		check.add_theme_color_override("font_color", ApplePalette.GOLD_BRIGHT)
		check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_row.add_child(check)
	var cover_title := Label.new()
	cover_title.text = _cover_glyph(id)
	cover_title.add_theme_font_size_override("font_size", 32)
	cover_title.add_theme_color_override("font_color", Color("#F2EDE6", 0.96))
	cover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cover_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover_title.offset_left = 16; cover_title.offset_top = 46
	cover_inner.add_child(cover_title)
	var cover_sub := Label.new()
	cover_sub.text = _cover_sub(id)
	cover_sub.add_theme_font_size_override("font_size", 12)
	cover_sub.add_theme_color_override("font_color", Color("#9AA3B2"))
	cover_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover_sub.offset_left = 16; cover_sub.offset_top = 82
	cover_inner.add_child(cover_sub)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var body_pad := Panel.new()
	body_pad.add_theme_stylebox_override("panel", _body_pad_style(available and id == _selected_id))
	body.add_child(body_pad)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	root_v.add_child(margin)
	margin.add_child(body)
	var title := Label.new()
	title.text = g.get("name", id)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ApplePalette.LABEL if available else ApplePalette.LABEL_DIM)
	body.add_child(title)
	var desc := Label.new()
	desc.text = _game_desc(id, available)
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", ApplePalette.LABEL_SECONDARY if available else ApplePalette.LABEL_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	meta.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.add_child(meta)
	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 9)
	dot.add_theme_color_override("font_color", ApplePalette.TEAL if available else ApplePalette.LABEL_DIM)
	meta.add_child(dot)
	var meta_lbl := Label.new()
	meta_lbl.text = "2 玩家  ·  策略" if available else "敬请期待  ·  策略"
	meta_lbl.add_theme_font_size_override("font_size", 12)
	meta_lbl.add_theme_color_override("font_color", ApplePalette.LABEL_TERTIARY)
	meta.add_child(meta_lbl)
	if available:
		var cta := Label.new()
		cta.text = "点击选择  →" if id != _selected_id else "已选定  ✓"
		cta.add_theme_font_size_override("font_size", 13)
		cta.add_theme_color_override("font_color", ApplePalette.GOLD if id != _selected_id else ApplePalette.GOLD_BRIGHT)
		cta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		meta.add_child(cta)
	if available:
		card.gui_input.connect(_on_card_input.bind(id))
		card.mouse_entered.connect(func() -> void:
			if id != _selected_id:
				var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				tw.tween_property(card, "position:y", card.position.y - 3, 0.18)
				tw.parallel().tween_property(card, "scale", Vector2(1.012, 1.012), 0.18)
		)
		card.mouse_exited.connect(func() -> void:
			var tw2 := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw2.tween_property(card, "position:y", card.position.y, 0.18)
			tw2.parallel().tween_property(card, "scale", Vector2.ONE, 0.18)
		)
	else:
		card.modulate = Color(1, 1, 1, 0.62)
	return card

func _body_pad_style(_selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.content_margin_left = 0; s.content_margin_top = 0; s.content_margin_right = 0; s.content_margin_bottom = 0
	return s

func _cover_glyph(id: String) -> String:
	match id:
		"xiangqi": return "象  棋"
		"chess_placeholder": return "CHESS"
		"go_placeholder": return "围  棋"
		_: return id.substr(0, 2).to_upper()

func _cover_sub(id: String) -> String:
	match id:
		"xiangqi": return "XIANGQI  ·  楚河汉界"
		"chess_placeholder": return "INTERNATIONAL CHESS"
		"go_placeholder": return "GO  ·  19 × 19"
		_: return id

func _game_desc(id: String, available: bool) -> String:
	match id:
		"xiangqi": return "中国象棋 · 完整规则与 AI，支持 LAN 对战与将军高亮。长按拖动更好玩。" if available else ""
		"chess_placeholder": return "国际象棋正在打磨中，敬请期待收藏级棋盘与大师 AI。"
		"go_placeholder": return "围棋 19 路棋盘与定式库筹备中，为长考而生。"
		_: return "" if not available else "即将上线"

func _on_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_id = id
		_sfx("select")
		_update_selection_visuals()
		_update_hint()
		var card: Control = _card_nodes.get(id, null)
		if card != null:
			var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			card.scale = Vector2(0.98, 0.98)
			tw.tween_property(card, "scale", Vector2.ONE, 0.22)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_selected_id = id
		_sfx("select")
		_update_selection_visuals()
		_update_hint()
		accept_event()

func _update_selection_visuals() -> void:
	for id in _card_nodes.keys():
		var card: Panel = _card_nodes[id] as Panel
		if card == null:
			continue
		var is_sel: bool = id == _selected_id and _card_nodes.has(id) and Registry.GAMES.get(id, {}).get("status", "") == "available"
		var sb := card.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var flat: StyleBoxFlat = sb as StyleBoxFlat
			if is_sel:
				flat.bg_color = Color("#1A1F18")
				flat.border_color = ApplePalette.GOLD
				flat.shadow_color = ApplePalette.GLOW_GOLD
				flat.shadow_size = 18
			else:
				flat.bg_color = Color("#151A14")
				flat.border_color = ApplePalette.SEPARATOR
				flat.shadow_color = ApplePalette.SHADOW_SOFT
				flat.shadow_size = 10
	if _card_nodes.size() > 0:
		call_deferred("_deferred_rebuild_grid")

func _deferred_rebuild_grid() -> void:
	if not is_inside_tree():
		return
	var sel: String = _selected_id
	_build_grid_no_anim(sel)

func _build_grid_no_anim(sel: String) -> void:
	_selected_id = sel
	for c in _grid.get_children():
		c.queue_free()
	_card_nodes.clear()
	var games: Array = _game_registry.call("get_available_games")
	for id in Registry.GAMES.keys():
		var entry: Dictionary = Registry.GAMES[id]
		if entry.get("status", "") != "available" and not games.any(func(gg: Dictionary) -> bool: return gg.get("id", "") == id):
			var cp2: Dictionary = entry.duplicate()
			cp2["id"] = id
			games.append(cp2)
	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av_a: bool = a.get("status", "") == "available"
		var av_b: bool = b.get("status", "") == "available"
		if av_a != av_b:
			return av_a
		return str(a.get("name", "")) < str(b.get("name", "")))
	for g in games:
		var id2: String = g.get("id", "")
		var card2 := _make_game_card(g)
		_grid.add_child(card2)
		_card_nodes[id2] = card2

func _update_hint() -> void:
	var g: Dictionary = _game_registry.call("get_game", _selected_id)
	var desc: String = g.get("description", "")
	if desc == "":
		match _selected_id:
			"xiangqi": desc = "中国象棋 · 已就绪  ·  支持人机、局域网联机。长按拖动棋子更顺手。"
			_: desc = ""
	_set_hint(desc, false)

func _set_hint(text: String, is_error: bool) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", ApplePalette.DANGER if is_error else ApplePalette.LABEL_TERTIARY)
	_hint.add_theme_font_size_override("font_size", 13)
	if is_error:
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_hint.modulate.a = 0.0
		tw.tween_property(_hint, "modulate:a", 1.0, 0.22)

func _enter_game() -> void:
	var g: Dictionary = _game_registry.call("get_game", _selected_id)
	var scene: String = g.get("scene", "")
	if scene == "" or not bool(_game_registry.call("is_available", _selected_id)):
		_set_hint("该游戏仍在打磨中，敬请期待。", true)
		_sfx("invalid")
		return
	_sfx("tap")
	_app_state.set("selected_game", _selected_id)
	get_tree().change_scene_to_file(scene)

func _on_ai() -> void:
	_sfx("tap")
	_app_state.call("set_mode", 1)
	_enter_game()

func _on_create_room() -> void:
	_sfx("tap")
	var code: String = _room_manager.create_room(_selected_id)
	if code == "":
		_sfx("invalid")
		return
	_in_room = true
	_room_code_label.text = code
	_room_sub.text = "将此房间码分享给同一 Wi-Fi 下的好友"
	_room_info.visible = true
	_lan_section.visible = true
	_set_hint("房间 %s 已创建，等待对手加入…" % code, false)
	_animate_room_info()

func _on_browse_rooms() -> void:
	_sfx("tap")
	_lan_section.visible = not _lan_section.visible
	if _lan_section.visible:
		_lan_discovery.start_listening()
		_refresh_rooms()
		_animate_lan_section()
	else:
		if not _in_room:
			_lan_discovery.stop()

func _animate_room_info() -> void:
	_room_info.modulate.a = 0.0
	_room_info.position.y += 8
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_room_info, "modulate:a", 1.0, 0.32)
	tw.parallel().tween_property(_room_info, "position:y", _room_info.position.y - 8, 0.32)

func _animate_lan_section() -> void:
	_lan_section.modulate.a = 0.0
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_lan_section, "modulate:a", 1.0, 0.28)

func _on_rooms_updated(_rooms: Array) -> void:
	_refresh_rooms()

func _refresh_rooms() -> void:
	for c in _rooms_list.get_children():
		c.queue_free()
	var rooms: Array = _lan_discovery.get_rooms()
	var filtered: Array = rooms.filter(func(r: Dictionary) -> bool: return r.get("game_id", "xiangqi") == _selected_id)
	var empty_visible: bool = filtered.is_empty()
	_rooms_empty.visible = empty_visible
	if empty_visible:
		var found: Label = _rooms_empty.get_node_or_null("EmptyInner/EmptyLabel") as Label
		if found != null:
			found.text = "暂未发现房间"
	for r in filtered:
		var row := _make_room_row(r)
		_rooms_list.add_child(row)

func _make_room_row(info: Dictionary) -> Control:
	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#141A14")
	sb.corner_radius_top_left = 14; sb.corner_radius_top_right = 14; sb.corner_radius_bottom_right = 14; sb.corner_radius_bottom_left = 14
	sb.border_color = ApplePalette.SEPARATOR; sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.content_margin_left = 14; sb.content_margin_top = 12; sb.content_margin_right = 14; sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(hbox)
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(44, 44)
	var av_sb := StyleBoxFlat.new()
	av_sb.bg_color = Color("#1A2332")
	av_sb.corner_radius_top_left = 22; av_sb.corner_radius_top_right = 22; av_sb.corner_radius_bottom_right = 22; av_sb.corner_radius_bottom_left = 22
	av_sb.border_color = ApplePalette.HAIRLINE_GOLD; av_sb.border_width_left = 1; av_sb.border_width_top = 1; av_sb.border_width_right = 1; av_sb.border_width_bottom = 1
	avatar.add_theme_stylebox_override("panel", av_sb)
	hbox.add_child(avatar)
	var av_lbl := Label.new()
	av_lbl.text = str(info.get("host_name", "Host")).substr(0, 1).to_upper()
	av_lbl.add_theme_font_size_override("font_size", 15)
	av_lbl.add_theme_color_override("font_color", ApplePalette.GOLD_BRIGHT)
	av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.add_child(av_lbl)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	hbox.add_child(mid)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	mid.add_child(top_row)
	var code_lbl := Label.new()
	code_lbl.text = info.get("room_code", "--")
	code_lbl.add_theme_font_size_override("font_size", 17)
	code_lbl.add_theme_color_override("font_color", ApplePalette.LABEL)
	top_row.add_child(code_lbl)
	var live := Panel.new()
	live.custom_minimum_size = Vector2(0, 20)
	var live_sb := StyleBoxFlat.new()
	live_sb.bg_color = Color("#0E1A15")
	live_sb.corner_radius_top_left = 10; live_sb.corner_radius_top_right = 10; live_sb.corner_radius_bottom_right = 10; live_sb.corner_radius_bottom_left = 10
	live_sb.border_color = Color("#2EC4B6", 0.22); live_sb.border_width_left = 1; live_sb.border_width_top = 1; live_sb.border_width_right = 1; live_sb.border_width_bottom = 1
	live_sb.content_margin_left = 8; live_sb.content_margin_top = 2; live_sb.content_margin_right = 8; live_sb.content_margin_bottom = 2
	live.add_theme_stylebox_override("panel", live_sb)
	top_row.add_child(live)
	var live_lbl := Label.new()
	live_lbl.text = "● 可加入"
	live_lbl.add_theme_font_size_override("font_size", 11)
	live_lbl.add_theme_color_override("font_color", ApplePalette.TEAL)
	live_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	live_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	live.add_child(live_lbl)
	var host_lbl := Label.new()
	host_lbl.text = "%s  ·  %s" % [info.get("host_name", "Host"), info.get("ip", "")]
	host_lbl.add_theme_font_size_override("font_size", 12)
	host_lbl.add_theme_color_override("font_color", ApplePalette.LABEL_TERTIARY)
	mid.add_child(host_lbl)
	var btn := Button.new()
	btn.text = "加入"
	btn.custom_minimum_size = Vector2(92, 48)
	AppleStyle.apply_primary_button(btn)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func() -> void: _sfx("tap"); _on_join_discovered(info))
	hbox.add_child(btn)
	card.custom_minimum_size = Vector2(0, 72)
	return card

func _on_join_discovered(info: Dictionary) -> void:
	var err: Error = _room_manager.join_room_at(info["ip"], int(info["port"]), info["room_code"])
	if err != OK:
		_sfx("invalid")
		return
	_on_room_joined(info["room_code"])

func _on_join_code() -> void:
	var code: String = _room_code_input.text.strip_edges().to_upper()
	if code == "":
		_set_hint("请输入 6 位房间码", true)
		_sfx("invalid")
		return
	_sfx("tap")
	var already_discovered: bool = not _lan_discovery.find_room_by_code(code).is_empty()
	var err: Error = _room_manager.join_room_by_code(code)
	if err != OK:
		_sfx("invalid")
		return
	if not already_discovered:
		_set_hint("正在加入 %s…" % code, false)
		return
	_on_room_joined(code)

func _on_direct_join() -> void:
	var ip: String = _direct_ip_input.text.strip_edges()
	if ip == "":
		_set_hint("请输入 IP 地址", true)
		_sfx("invalid")
		return
	_sfx("tap")
	var port: int = 7777
	if ip.contains(":"):
		var parts: PackedStringArray = ip.split(":")
		ip = parts[0]
		port = int(parts[1])
	var err: Error = _room_manager.join_direct(ip, port)
	if err != OK:
		_sfx("invalid")
		return
	_on_room_joined("%s:%d" % [ip, port])

func _on_room_created(code: String, _port: int) -> void:
	_in_room = true
	_room_code_label.text = code
	_room_info.visible = true
	_lan_section.visible = true
	_sfx("select")
	_animate_room_info()

func _on_room_joined(code: String) -> void:
	_in_room = true
	_room_code_label.text = code
	_room_sub.text = "已加入房间 %s  ·  点击开始对局" % code
	_room_info.visible = true
	%BtnStartGame.text = "开始对局"
	_sfx("select")
	_animate_room_info()

func _on_leave_room() -> void:
	_sfx("tap")
	_room_manager.leave_room()
	_in_room = false
	_room_info.visible = false
	_set_hint("已离开房间", false)
	if _lan_section.visible:
		_lan_discovery.start_listening()

func _on_start_game() -> void:
	_enter_game()

class _CoverArt extends Control:
	var game_id: String = "xiangqi"
	func _draw() -> void:
		var r: Rect2 = get_rect()
		match game_id:
			"xiangqi":
				_draw_sheen(r, Color("#D4A574", 0.08), Color(0, 0, 0, 0))
				var s: float = min(r.size.x, r.size.y) * 0.18
				var ox: float = r.size.x * 0.62
				var oy: float = r.size.y * 0.18
				var col: Color = Color("#F2EDE6", 0.10)
				for i in range(4):
					draw_line(Vector2(ox + i * s * 0.55, oy), Vector2(ox + i * s * 0.55, oy + 3 * s * 0.55), col, 1.0)
					draw_line(Vector2(ox, oy + i * s * 0.55), Vector2(ox + 3 * s * 0.55, oy + i * s * 0.55), col, 1.0)
				draw_circle(Vector2(ox + 1.1 * s, oy + 1.1 * s), 10, Color("#D4A574", 0.18))
				draw_circle(Vector2(ox + 1.1 * s, oy + 1.1 * s), 6, Color("#F2EDE6", 0.90))
			"chess_placeholder":
				_draw_sheen(r, Color("#2EC4B6", 0.07), Color(0, 0, 0, 0))
				draw_circle(Vector2(r.size.x * 0.72, r.size.y * 0.45), 18, Color("#FFFFFF", 0.06))
				draw_circle(Vector2(r.size.x * 0.58, r.size.y * 0.58), 12, Color("#2EC4B6", 0.14))
			"go_placeholder":
				_draw_sheen(r, Color("#8C6A3A", 0.08), Color(0, 0, 0, 0))
				var gcol: Color = Color("#F2EDE6", 0.08)
				var gx: float = r.size.x * 0.60
				var gy: float = r.size.y * 0.20
				var gs: float = r.size.x * 0.08
				for i in range(4):
					draw_line(Vector2(gx + i * gs, gy), Vector2(gx + i * gs, gy + 3 * gs), gcol, 1.0)
					draw_line(Vector2(gx, gy + i * gs), Vector2(gx + 3 * gs, gy + i * gs), gcol, 1.0)
				draw_circle(Vector2(gx + 1.0 * gs, gy + 1.5 * gs), 6, Color("#1A1F2B"))
				draw_circle(Vector2(gx + 2.0 * gs, gy + 1.0 * gs), 6, Color("#FFF6EE"))
			_:
				_draw_sheen(r, Color("#FFFFFF", 0.04), Color(0, 0, 0, 0))
	func _draw_sheen(r: Rect2, a: Color, _b: Color) -> void:
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(r.size.x * 0.35, 0), Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y * 0.55), Vector2(r.size.x * 0.55, r.size.y * 0.0)
		])
		draw_colored_polygon(pts, a)

class _HeroBoardPreview extends Control:
	func _draw() -> void:
		var r: Rect2 = get_rect()
		var pad: float = 12.0
		var board_rect := Rect2(Vector2(pad, pad), r.size - Vector2(pad * 2, pad * 2))
		draw_rect(board_rect, Color("#1A1208"))
		var inner := board_rect.grow(-6)
		draw_rect(inner, Color("#F7F0E0"))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), Color("#D9C9A3", 0.9))
		draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), Color("#D9C9A3", 0.7))
		var cell_w: float = (inner.size.x - 12) / 8.0
		var cell_h: float = (inner.size.y - 12) / 9.0
		var ox: float = inner.position.x + 6
		var oy: float = inner.position.y + 6
		var line: Color = Color("#2B1E0F", 0.62)
		var soft: Color = Color("#2B1E0F", 0.18)
		var river_top: float = oy + 4 * cell_h
		var river_bot: float = oy + 5 * cell_h
		draw_rect(Rect2(Vector2(ox - 2, river_top), Vector2(8 * cell_w + 4, river_bot - river_top)), Color("#2EC4B6", 0.07))
		for yy in range(10):
			var y: float = oy + yy * cell_h
			draw_line(Vector2(ox, y), Vector2(ox + 8 * cell_w, y), line, 1.0)
		for xx in range(9):
			var x: float = ox + xx * cell_w
			if xx == 0 or xx == 8:
				draw_line(Vector2(x, oy), Vector2(x, oy + 9 * cell_h), line, 1.0)
			else:
				draw_line(Vector2(x, oy), Vector2(x, river_top), soft, 1.0)
				draw_line(Vector2(x, river_bot), Vector2(x, oy + 9 * cell_h), soft, 1.0)
		draw_line(Vector2(ox + 3 * cell_w, oy), Vector2(ox + 5 * cell_w, oy + 2 * cell_h), line, 1.0)
		draw_line(Vector2(ox + 5 * cell_w, oy), Vector2(ox + 3 * cell_w, oy + 2 * cell_h), line, 1.0)
		draw_line(Vector2(ox + 3 * cell_w, oy + 7 * cell_h), Vector2(ox + 5 * cell_w, oy + 9 * cell_h), line, 1.0)
		draw_line(Vector2(ox + 5 * cell_w, oy + 7 * cell_h), Vector2(ox + 3 * cell_w, oy + 9 * cell_h), line, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(ox + 2.2 * cell_w, (river_top + river_bot) / 2 + 4), "楚河  ·  汉界", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#2B1E0F", 0.38))
		var f: Font = ThemeDB.fallback_font
		_draw_mini_piece(Vector2(ox + 4 * cell_w, oy + 0 * cell_h), true, "将", f)
		_draw_mini_piece(Vector2(ox + 4 * cell_w, oy + 9 * cell_h), false, "帅", f)
		_draw_mini_piece(Vector2(ox + 0 * cell_w, oy + 0 * cell_h), true, "車", f)
		_draw_mini_piece(Vector2(ox + 8 * cell_w, oy + 9 * cell_h), false, "車", f)
		_draw_mini_piece(Vector2(ox + 1 * cell_w, oy + 7 * cell_h), false, "炮", f)
		var ac: Color = Color("#D4A574", 0.55)
		var rr: float = 8.0
		draw_line(inner.position + Vector2(rr, 0), inner.position, ac, 1.0)
		draw_line(inner.position, inner.position + Vector2(0, rr), ac, 1.0)
		draw_line(Vector2(inner.position.x + inner.size.x - rr, inner.position.y), Vector2(inner.position.x + inner.size.x, inner.position.y), ac, 1.0)
		draw_line(Vector2(inner.position.x + inner.size.x, inner.position.y), Vector2(inner.position.x + inner.size.x, inner.position.y + rr), ac, 1.0)
	func _draw_mini_piece(center: Vector2, is_red: bool, label: String, font: Font) -> void:
		draw_circle(center + Vector2(0, 1), 9, Color("#000000", 0.18))
		var ring: Color = Color("#C0392B") if is_red else Color("#1A1F2B")
		draw_circle(center, 9, ring)
		draw_circle(center, 7, Color.WHITE if is_red else Color("#EEF2F7"))
		var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
		draw_string(font, center - Vector2(ts.x / 2, -ts.y / 3.2), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, ring)
