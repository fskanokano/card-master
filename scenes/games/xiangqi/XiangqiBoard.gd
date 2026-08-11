extends Control
class_name XiangqiBoard
## XiangqiBoard — Enterprise luxury rendering.
## 深胡桃木外框 + 羊皮纸棋面 + 鎏金细线，棋子立体浮雕。

signal try_move(from: Vector2i, to: Vector2i)
signal square_selected(pos: Vector2i)

var board: Array = []
var selected: Vector2i = Vector2i(-1, -1)
var legal_targets: Array[Vector2i] = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)
var interactable: bool = true

var _cell: float = 56.0
var _origin: Vector2 = Vector2(28, 28)
var _anim_tween: Tween = null
var _anim_from: Vector2i = Vector2i(-1, -1)
var _anim_to: Vector2i = Vector2i(-1, -1)
var _anim_piece: int = 0
var _anim_pos_from: Vector2 = Vector2.ZERO
var _anim_pos_to: Vector2 = Vector2.ZERO
var _anim_progress: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(9 * _cell + 56, 10 * _cell + 56)
	mouse_filter = MOUSE_FILTER_STOP

func set_board(b: Array) -> void:
	board = b
	queue_redraw()

func set_selection(sel: Vector2i, targets: Array[Vector2i]) -> void:
	selected = sel
	legal_targets = targets
	queue_redraw()

func set_last_move(f: Vector2i, t: Vector2i) -> void:
	last_move_from = f
	last_move_to = t
	queue_redraw()

func animate_move(from: Vector2i, to: Vector2i, piece: int = 0) -> void:
	if from.x < 0 or to.x < 0:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	var p: int = piece if piece != 0 else (board[from.y][from.x] if from.y >= 0 and from.y < 10 and from.x >= 0 and from.x < 9 else 0)
	_anim_from = from
	_anim_to = to
	_anim_piece = p
	_anim_pos_from = board_to_local(from.x, from.y)
	_anim_pos_to = board_to_local(to.x, to.y)
	_anim_progress = 0.0
	_anim_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.tween_property(self, "_anim_progress", 1.0, 0.26)
	_anim_tween.tween_callback(func() -> void:
		_anim_from = Vector2i(-1, -1)
		_anim_to = Vector2i(-1, -1)
		_anim_piece = 0
		_anim_progress = 0.0
		queue_redraw()
	)
	queue_redraw()

func board_to_local(bx: int, by: int) -> Vector2:
	return Vector2(_origin.x + bx * _cell, _origin.y + by * _cell)

func local_to_board(p: Vector2) -> Vector2i:
	return Vector2i(int(round((p.x - _origin.x) / _cell)), int(round((p.y - _origin.y) / _cell)))

func _gui_input(event: InputEvent) -> void:
	if not interactable:
		return
	if _anim_piece != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2i = local_to_board(event.position)
		if not XiangqiLogic.inside_board(pos.x, pos.y):
			return
		if selected.x != -1:
			for t in legal_targets:
				if t == pos:
					try_move.emit(selected, pos)
					return
			var p: int = board[pos.y][pos.x]
			if p != 0:
				square_selected.emit(pos)
			else:
				square_selected.emit(Vector2i(-1, -1))
		else:
			square_selected.emit(pos)
		accept_event()

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	# Outer walnut frame
	_draw_rounded_rect(outer, 22, ApplePalette.BOARD_FRAME)
	# Gold hairline inset
	_draw_rounded_rect_outline(outer.grow(-1), 22, ApplePalette.BOARD_FRAME_HIGHLIGHT, 1.0)
	# Inner highlight on top edge
	draw_line(Vector2(14, 8), Vector2(size.x - 14, 8), Color("#D4A574", 0.14), 1.0)
	# Parchment field
	var paper := Rect2(Vector2(14, 14), size - Vector2(28, 28))
	_draw_rounded_rect(paper, 16, ApplePalette.BOARD_PAPER)
	# Paper texture — subtle horizontal grain
	var grain: Color = Color("#8C6A3A", 0.06)
	for gy in range(8):
		var yy: float = paper.position.y + paper.size.y * (0.14 + gy * 0.11)
		draw_line(Vector2(paper.position.x + 10, yy), Vector2(paper.position.x + paper.size.x - 10, yy + 0.6), grain, 1.0)
	# Paper inner shadow top
	draw_line(paper.position + Vector2(0, 1), paper.position + Vector2(paper.size.x, 1), Color("#000000", 0.07), 1.0)
	draw_line(paper.position + Vector2(1, 0), paper.position + Vector2(1, paper.size.y), Color("#000000", 0.05), 1.0)

	# Grid
	var river_top: float = _origin.y + 4 * _cell
	var river_bot: float = _origin.y + 5 * _cell
	var river_rect := Rect2(Vector2(_origin.x - 10, river_top), Vector2(8 * _cell + 20, river_bot - river_top))
	draw_rect(river_rect, ApplePalette.BOARD_RIVER_TINT)
	var line_col: Color = ApplePalette.BOARD_LINE
	var line_soft: Color = ApplePalette.BOARD_LINE_SOFT
	for y in range(10):
		var yy: float = _origin.y + y * _cell
		draw_line(Vector2(_origin.x, yy), Vector2(_origin.x + 8 * _cell, yy), line_col, 1.2 if y == 0 or y == 9 else 1.0)
	for x in range(9):
		var xx: float = _origin.x + x * _cell
		if x == 0 or x == 8:
			draw_line(Vector2(xx, _origin.y), Vector2(xx, _origin.y + 9 * _cell), line_col, 1.2)
		else:
			draw_line(Vector2(xx, _origin.y), Vector2(xx, river_top), line_soft, 1.0)
			draw_line(Vector2(xx, river_bot), Vector2(xx, _origin.y + 9 * _cell), line_soft, 1.0)
	# Palace diagonals — slightly bolder, gold-tinged
	var palace_col: Color = Color("#2B1E0F", 0.62)
	for seg in [[Vector2i(3, 0), Vector2i(5, 2)], [Vector2i(5, 0), Vector2i(3, 2)], [Vector2i(3, 7), Vector2i(5, 9)], [Vector2i(5, 7), Vector2i(3, 9)]]:
		var a: Vector2 = board_to_local(seg[0].x, seg[0].y)
		var b2: Vector2 = board_to_local(seg[1].x, seg[1].y)
		draw_line(a, b2, palace_col, 1.2)
	# Corner marks (the classic L)
	for p in [[0, 2], [2, 2], [6, 2], [8, 2], [0, 7], [2, 7], [6, 7], [8, 7], [1, 3], [7, 3]]:
		_draw_corner_marks(p[0], p[1])
	# River calligraphy
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(_origin.x + 1.45 * _cell, (river_top + river_bot) / 2 + 5), "楚  河", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ApplePalette.BOARD_RIVER_INK)
	draw_string(font, Vector2(_origin.x + 5.35 * _cell, (river_top + river_bot) / 2 + 5), "汉  界", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ApplePalette.BOARD_RIVER_INK)
	draw_string(font, Vector2(_origin.x + 3.05 * _cell, (river_top + river_bot) / 2 + 5), "·", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#2B1E0F", 0.22))
	# Last move — warm gold wash
	if last_move_from.x != -1:
		_highlight_square(last_move_from, Color("#D4A574", 0.16), 12)
	if last_move_to.x != -1:
		_highlight_square(last_move_to, Color("#D4A574", 0.22), 12)
	# Selection — gold ring + soft teal fill
	if selected.x != -1:
		_highlight_square(selected, Color("#2EC4B6", 0.08), 12)
		_draw_square_ring(selected, ApplePalette.GOLD, 2.0, 12)
		# inner glow
		_draw_square_ring(selected, Color("#D4A574", 0.22), 6.0, 12)
	# Legal targets
	for t in legal_targets:
		var c: Vector2 = board_to_local(t.x, t.y)
		var is_capture: bool = board[t.y][t.x] != 0
		if is_capture:
			# capture: red outer ring + gold inner
			draw_arc(c, 20, 0, TAU, 32, Color("#E8583A", 0.92), 2.4)
			draw_arc(c, 17, 0, TAU, 32, Color("#D4A574", 0.45), 1.0)
			draw_circle(c, 5, Color("#E8583A", 0.18))
		else:
			# move: teal dot with gold halo + white center
			draw_circle(c, 9, Color("#2EC4B6", 0.14))
			draw_circle(c, 7, Color("#2EC4B6", 0.92))
			draw_circle(c, 3.4, Color.WHITE)
			draw_arc(c, 7, 0, TAU, 24, Color("#D4A574", 0.35), 1.0)
	if board.is_empty():
		return
	for y in range(10):
		for x in range(9):
			var p: int = board[y][x]
			if p == 0:
				continue
			if _anim_piece != 0 and Vector2i(x, y) == _anim_from:
				continue
			_draw_piece(board_to_local(x, y), p, font)
	if _anim_piece != 0 and _anim_from.x != -1 and _anim_to.x != -1 and _anim_progress > 0.0:
		var interp_pos: Vector2 = _anim_pos_from.lerp(_anim_pos_to, _anim_progress)
		_draw_piece(interp_pos, _anim_piece, font)

func _draw_corner_marks(bx: int, by: int) -> void:
	var c: Vector2 = board_to_local(bx, by)
	var s: float = 7.0
	var gap: float = 3.5
	var col: Color = Color("#2B1E0F", 0.38)
	# four L's around the intersection, but only if not on edge pieces that would overlap palace? Keep classic positions: pawns/cannons
	var dirs: Array = [[-1, -1], [1, -1], [-1, 1], [1, 1]]
	for d in dirs:
		var dx: int = d[0]; var dy: int = d[1]
		# skip if would go off board visual
		var px: float = c.x + dx * gap
		var py: float = c.y + dy * gap
		# horizontal arm
		draw_line(Vector2(px, py), Vector2(px + dx * s, py), col, 1.0)
		# vertical arm
		draw_line(Vector2(px, py), Vector2(px, py + dy * s), col, 1.0)

func _draw_piece(center: Vector2, p: int, font: Font) -> void:
	var is_red: bool = p > 0
	# Drop shadow
	draw_circle(center + Vector2(0, 3), 22, ApplePalette.PIECE_SHADOW)
	draw_circle(center + Vector2(0, 1.2), 22, Color("#000000", 0.12))
	# Outer ring — gold for red, steel for black
	var ring_col: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	var ring_highlight: Color = Color("#E7A87A") if is_red else Color("#4A5A73")
	draw_circle(center, 22, ring_col)
	# bevel highlight
	draw_arc(center + Vector2(-0.6, -0.8), 21, 1.15 * PI, 1.85 * PI, 20, ring_highlight, 1.2)
	# Inlay
	var inlay: Color = ApplePalette.PIECE_RED_INLAY if is_red else ApplePalette.PIECE_BLACK_INLAY
	draw_circle(center, 18.8, inlay)
	# Inner gold chamfer
	draw_arc(center, 18.8, 0, TAU, 32, ApplePalette.PIECE_GOLD_RING, 1.0)
	draw_arc(center, 15.6, 0, TAU, 32, Color("#000000", 0.06), 1.0)
	# Slight radial highlight top-left
	draw_circle(center + Vector2(-5, -6), 5, Color("#FFFFFF", 0.10))
	var label: String = _piece_label(p)
	var fs: int = 20
	var disc: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	# subtle text shadow for legibility
	var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var base: Vector2 = center - Vector2(ts.x / 2, -ts.y / 3.0)
	draw_string(font, base + Vector2(0, 1), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color("#000000", 0.18))
	draw_string(font, base, label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, disc)

func _highlight_square(pos: Vector2i, col: Color, r: float) -> void:
	var c: Vector2 = board_to_local(pos.x, pos.y)
	var rect := Rect2(c - Vector2(23, 23), Vector2(46, 46))
	_draw_rounded_rect(rect, r, col)

func _draw_square_ring(pos: Vector2i, col: Color, w: float, r: float) -> void:
	var c: Vector2 = board_to_local(pos.x, pos.y)
	var rect := Rect2(c - Vector2(23, 23), Vector2(46, 46))
	_draw_rounded_rect_outline(rect, r, col, w)

func _draw_rounded_rect(rect: Rect2, radius: float, col: Color) -> void:
	draw_rect(rect, col)
	for corner in [rect.position, Vector2(rect.position.x + rect.size.x - radius * 2, rect.position.y), Vector2(rect.position.x, rect.position.y + rect.size.y - radius * 2), rect.position + rect.size - Vector2(radius * 2, radius * 2)]:
		draw_circle(corner + Vector2(radius, radius), radius, col)

func _draw_rounded_rect_outline(rect: Rect2, radius: float, col: Color, w: float) -> void:
	var r: float = radius
	draw_line(rect.position + Vector2(r, 0), rect.position + Vector2(rect.size.x - r, 0), col, w)
	draw_line(rect.position + Vector2(rect.size.x, r), rect.position + Vector2(rect.size.x, rect.size.y - r), col, w)
	draw_line(rect.position + Vector2(rect.size.x - r, rect.size.y), rect.position + Vector2(r, rect.size.y), col, w)
	draw_line(rect.position + Vector2(0, rect.size.y - r), rect.position + Vector2(0, r), col, w)
	draw_arc(rect.position + Vector2(r, r), r, PI, 1.5 * PI, 16, col, w)
	draw_arc(rect.position + Vector2(rect.size.x - r, r), r, 1.5 * PI, TAU, 16, col, w)
	draw_arc(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, 0, 0.5 * PI, 16, col, w)
	draw_arc(rect.position + Vector2(r, rect.size.y - r), r, 0.5 * PI, PI, 16, col, w)

func _piece_label(p: int) -> String:
	var t: int = XiangqiLogic.piece_type(p)
	if p > 0:
		match t:
			XiangqiLogic.KING: return "帅"
			XiangqiLogic.ADVISOR: return "仕"
			XiangqiLogic.ELEPHANT: return "相"
			XiangqiLogic.HORSE: return "马"
			XiangqiLogic.CHARIOT: return "车"
			XiangqiLogic.CANNON: return "炮"
			XiangqiLogic.PAWN: return "兵"
			_: return "?"
	else:
		match t:
			XiangqiLogic.KING: return "将"
			XiangqiLogic.ADVISOR: return "士"
			XiangqiLogic.ELEPHANT: return "象"
			XiangqiLogic.HORSE: return "馬"
			XiangqiLogic.CHARIOT: return "車"
			XiangqiLogic.CANNON: return "砲"
			XiangqiLogic.PAWN: return "卒"
			_: return "?"
