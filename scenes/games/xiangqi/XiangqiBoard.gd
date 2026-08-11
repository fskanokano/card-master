extends Control
class_name XiangqiBoard
## Apple HIG board: warm paper, hairline ink grid, frosted chrome, SF piece glyphs.

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
var _anim_tween: Tween = null
var _anim_from: Vector2i = Vector2i(-1, -1)
var _anim_to: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	custom_minimum_size = Vector2(9 * _cell + 56, 10 * _cell + 56)
	mouse_filter = MOUSE_FILTER_STOP

func animate_move(from: Vector2i, to: Vector2i) -> void:
	if from.x == -1 or to.x == -1:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_from = from
	_anim_to = to
	# Start animation by setting board without the moving piece, then tween to final
	_board_view_ref = self
	_anim_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.tween_interval(0.25)
	_anim_tween.tween_callback(func() -> void:
		_anim_from = Vector2i(-1, -1)
		_anim_to = Vector2i(-1, -1)
		queue_redraw()
	)
	queue_redraw()

var _board_view_ref = null

func animate_move(from: Vector2i, to: Vector2i) -> void:
	if from.x == -1 or to.x == -1:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_from = from
	_anim_to = to
	# Start animation by setting board without the moving piece, then tween to final
	_board_view_ref = self
	_anim_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.tween_interval(0.25)
	_anim_tween.tween_callback(func() -> void:
		_anim_from = Vector2i(-1, -1)
		_anim_to = Vector2i(-1, -1)
		queue_redraw()
	)
	queue_redraw()

var _board_view_ref = null

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

func board_to_local(bx: int, by: int) -> Vector2:
	return Vector2(_origin.x + bx * _cell, _origin.y + by * _cell)

func local_to_board(p: Vector2) -> Vector2i:
	return Vector2i(int(round((p.x - _origin.x) / _cell)), int(round((p.y - _origin.y) / _cell)))

func _gui_input(event: InputEvent) -> void:
	if not interactable:
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
	# Card paper with soft shadow (Apple card)
	draw_rect(outer, Color.WHITE)
	# Inner board paper
	var paper := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	_draw_rounded_rect(paper, 16, ApplePalette.BOARD_PAPER)
	# Subtle border hairline
	_draw_rounded_rect_outline(paper, 16, ApplePalette.SEPARATOR, 1.0)
	# River tint band
	var river_top: float = _origin.y + 4 * _cell
	var river_bot: float = _origin.y + 5 * _cell
	var river_rect := Rect2(Vector2(_origin.x - 8, river_top), Vector2(8 * _cell + 16, river_bot - river_top))
	draw_rect(river_rect, ApplePalette.BOARD_RIVER_TINT)
	# Grid — hairlines
	var line_col: Color = ApplePalette.BOARD_LINE
	var line_soft: Color = ApplePalette.BOARD_LINE_SOFT
	for y in range(10):
		var yy: float = _origin.y + y * _cell
		draw_line(Vector2(_origin.x, yy), Vector2(_origin.x + 8 * _cell, yy), line_col, 1.0)
	for x in range(9):
		var xx: float = _origin.x + x * _cell
		if x == 0 or x == 8:
			draw_line(Vector2(xx, _origin.y), Vector2(xx, _origin.y + 9 * _cell), line_col, 1.0)
		else:
			draw_line(Vector2(xx, _origin.y), Vector2(xx, river_top), line_soft, 1.0)
			draw_line(Vector2(xx, river_bot), Vector2(xx, _origin.y + 9 * _cell), line_soft, 1.0)
	# Palace diagonals — slightly stronger
	for seg in [
		[Vector2i(3, 0), Vector2i(5, 2)], [Vector2i(5, 0), Vector2i(3, 2)],
		[Vector2i(3, 7), Vector2i(5, 9)], [Vector2i(5, 7), Vector2i(3, 9)],
	]:
		var a: Vector2 = board_to_local(seg[0].x, seg[0].y)
		var b2: Vector2 = board_to_local(seg[1].x, seg[1].y)
		draw_line(a, b2, line_col, 1.0)
	# River label — caption style
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(_origin.x + 1.6 * _cell, (river_top + river_bot) / 2 + 5), "River  ·  Chu He  Han Jie", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#3C3C43", 0.45))
	# Last move — soft amber wash, rounded
	if last_move_from.x != -1:
		_highlight_square(last_move_from, Color("#FFCC02", 0.22), 10)
	if last_move_to.x != -1:
		_highlight_square(last_move_to, Color("#FF9500", 0.20), 10)
	# Selection — blue focus ring
	if selected.x != -1:
		_highlight_square(selected, Color("#007AFF", 0.14), 10)
		_draw_square_ring(selected, ApplePalette.BLUE, 2.0, 10)
	# Legal targets — Apple dot / ring
	for t in legal_targets:
		var c: Vector2 = board_to_local(t.x, t.y)
		var is_capture: bool = board[t.y][t.x] != 0
		if is_capture:
			# Ruby ring for captures
			draw_arc(c, 18, 0, TAU, 32, Color("#FF3B30", 0.85), 2.2)
			draw_circle(c, 4, Color("#FF3B30", 0.22))
		else:
			draw_circle(c, 7, Color("#007AFF", 0.78))
			draw_circle(c, 3.2, Color.WHITE)
	# Pieces — animated disc + Chinese glyph
var anim_piece_offset := Vector2.ZERO
if _anim_from.x != -1 and _anim_to.x != -1:
	# During animation, compute interpolated position for the moving piece
pass  # Pieces drawn normally, animation handled by game controller

	if board.is_empty():
		return
	for y in range(10):
		for x in range(9):
			var p: int = board[y][x]
			if p == 0:
				continue
			var center: Vector2 = board_to_local(x, y)
			var is_red: bool = p > 0
			# Soft drop shadow
			draw_circle(center + Vector2(0, 2), 22, Color("#000000", 0.14))
			# Disc
			var disc_fill: Color = Color("#FF3B30") if is_red else Color("#1C1C1E")
			var disc_inner: Color = Color.WHITE
			draw_circle(center, 22, disc_fill)
			draw_circle(center, 19.5, disc_inner)
			draw_arc(center, 19.5, 0, TAU, 32, disc_fill, 1.8)
			# Inner hairline for depth
			draw_arc(center, 16.5, 0, TAU, 32, Color("#000000", 0.06), 1.0)
			var label: String = _piece_label(p)
			var fs: int = 20
			var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			# Slight weight: draw twice with 0.4px offset for semibold feel
			draw_string(font, center - Vector2(ts.x / 2, -ts.y / 3.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, disc_fill)
			# Removed offset draw for cleaner text

func _highlight_square(pos: Vector2i, col: Color, r: float) -> void:
	var c: Vector2 = board_to_local(pos.x, pos.y)
	var rect := Rect2(c - Vector2(22, 22), Vector2(44, 44))
	_draw_rounded_rect(rect, r, col)

func _draw_square_ring(pos: Vector2i, col: Color, w: float, r: float) -> void:
	var c: Vector2 = board_to_local(pos.x, pos.y)
	var rect := Rect2(c - Vector2(22, 22), Vector2(44, 44))
	_draw_rounded_rect_outline(rect, r, col, w)

func _draw_rounded_rect(rect: Rect2, radius: float, col: Color) -> void:
	# Approximate rounded rect via rect + 4 corner circles (cheap, no StyleBox in _draw)
	draw_rect(rect, col)
	# Overdraw corners with circles for rounding illusion — subtle
	for corner in [rect.position, Vector2(rect.position.x + rect.size.x - radius * 2, rect.position.y), Vector2(rect.position.x, rect.position.y + rect.size.y - radius * 2), rect.position + rect.size - Vector2(radius * 2, radius * 2)]:
		draw_circle(corner + Vector2(radius, radius), radius, col)

func _draw_rounded_rect_outline(rect: Rect2, radius: float, col: Color, w: float) -> void:
	# Hairline outline — draw 4 edges + 4 arcs
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
	var red: bool = p > 0
	match t:
		XiangqiLogic.KING: return "K" if red else "k"
		XiangqiLogic.ADVISOR: return "A" if red else "a"
		XiangqiLogic.ELEPHANT: return "E" if red else "e"
		XiangqiLogic.HORSE: return "H" if red else "h"
		XiangqiLogic.CHARIOT: return "R" if red else "r"
		XiangqiLogic.CANNON: return "C" if red else "c"
		XiangqiLogic.PAWN: return "P" if red else "p"
		_: return "?"
