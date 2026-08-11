extends Control
class_name XiangqiBoard
## XiangqiBoard — 真·手游级棋盘：占满全面屏、超大棋子、长按拖拽+落点脉冲+非法回弹
## 0 瞬移：飞行全程抛物线；拖拽长按 220ms 进入，手抬起非法点弹性回弹

signal try_move(from: Vector2i, to: Vector2i)
signal square_selected(pos: Vector2i)

var board: Array = []
var selected: Vector2i = Vector2i(-1, -1)
var legal_targets: Array[Vector2i] = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)
var interactable: bool = true

# ── Layout（为手机最大化） ─────────────────────────────────
var _cell: float = 52.0
var _origin: Vector2 = Vector2.ZERO
var _board_pad: float = 8.0
var _frame_thick: float = 10.0

# ── Animation state ──────────────────────────────────────
var _anim_tween: Tween = null
var _anim_from: Vector2i = Vector2i(-1, -1)
var _anim_to: Vector2i = Vector2i(-1, -1)
var _anim_piece: int = 0
var _anim_captured: int = 0
var _anim_is_capture: bool = false
var _anim_pos_from: Vector2 = Vector2.ZERO
var _anim_pos_to: Vector2 = Vector2.ZERO
var _anim_progress: float = 0.0:
	set(v):
		_anim_progress = v
		queue_redraw()
var _anim_capture_alpha: float = 1.0:
	set(v):
		_anim_capture_alpha = v
		queue_redraw()
var _anim_capture_scale: float = 1.0:
	set(v):
		_anim_capture_scale = v
		queue_redraw()
var _anim_capture_fx: float = 0.0:
	set(v):
		_anim_capture_fx = v
		queue_redraw()

# ── Touch / drag — 长按拖拽 + 回弹 ───────────────────────
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_pos: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _pending_drag: bool = false
var _long_press_time: float = 0.0
var _long_press_threshold: float = 0.22
var _drag_threshold: float = 10.0
var _touch_down_pos: Vector2 = Vector2.ZERO
var _pending_pos: Vector2i = Vector2i(-1, -1)
var _bounce_tween: Tween = null
var _pulse_t: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	resized.connect(_update_layout)
	_update_layout()
	set_process(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _process(delta: float) -> void:
	_pulse_t += delta * 2.4
	if _pulse_t > 1000:
		_pulse_t -= 1000
	# 长按检测：按住不动 220ms 自动进入拖拽
	if _pending_drag and not _is_dragging and _drag_from.x != -1:
		_long_press_time += delta
		if _long_press_time >= _long_press_threshold:
			_enter_drag()
	# 合法点脉冲重绘
	if legal_targets.size() > 0 or _is_dragging:
		queue_redraw()

func _update_layout() -> void:
	var avail: Vector2 = size
	if avail.x < 40 or avail.y < 40:
		avail = custom_minimum_size
		if avail.x < 40:
			# 回退到视口
			var vp: Vector2 = get_viewport_rect().size
			if vp.x > 40:
				avail = vp - Vector2(16, 16)
			else:
				avail = Vector2(360, 620)
	# 手机端优先放大，但必须为棋子最大视觉半径预留安全边距。
	# 棋子静止约 0.46 cell，拖拽会放大到 1.14 倍，因此按 0.53 cell 计算。
	var is_mobile: bool = OS.has_feature("mobile") or DisplayServer.get_name() in ["Android", "iOS"] or avail.x < 520
	var h_margin: float = 8.0 if is_mobile else 14.0
	var v_margin: float = 8.0 if is_mobile else 14.0
	var edge_clearance: float = 4.0
	var safe_w: float = max(280, avail.x - 2.0 * (_frame_thick + _board_pad + edge_clearance))
	var safe_h: float = max(360, avail.y - 2.0 * (_frame_thick + _board_pad + edge_clearance))
	# 8/9 是相邻交叉点跨度，额外的 1.06/1.06 是左右/上下两侧棋子半径。
	var cell_by_w: float = safe_w / 9.06
	var cell_by_h: float = safe_h / 10.06
	_cell = min(cell_by_w, cell_by_h)
	# 手机允许更大棋子，桌面也适当放大
	if is_mobile:
		# 手机棋盘优先按宽度放大，避免被桌面端的保守上限压缩
		_cell = clamp(_cell, 30.0, 110.0)
	else:
		_cell = clamp(_cell, 42.0, 72.0)
	var board_w: float = 8 * _cell
	var board_h: float = 9 * _cell
	var total_w: float = board_w + _frame_thick * 2 + _board_pad * 2
	var total_h: float = board_h + _frame_thick * 2 + _board_pad * 2
	var ox: float = _frame_thick + _board_pad + max(0, (avail.x - total_w) / 2.0)
	var oy: float = _frame_thick + _board_pad + max(0, (avail.y - total_h) / 2.0)
	_origin = Vector2(ox, oy)
	custom_minimum_size = Vector2(total_w + h_margin * 2, total_h + v_margin * 2)
	queue_redraw()

func get_board_pixel_size() -> Vector2:
	return Vector2(8 * _cell + _frame_thick * 2 + _board_pad * 2, 9 * _cell + _frame_thick * 2 + _board_pad * 2)

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

# ── 核心：流畅飞行（无瞬移） ──────────────────────────────
func animate_move(from: Vector2i, to: Vector2i, piece: int = 0, captured: int = 0) -> void:
	if from.x < 0 or to.x < 0:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_from = Vector2i(-1, -1)
		_anim_to = Vector2i(-1, -1)
		_anim_piece = 0
		_anim_captured = 0
	var p: int = piece if piece != 0 else (board[from.y][from.x] if from.y >= 0 and from.y < 10 and from.x >= 0 and from.x < 9 else 0)
	if p == 0:
		return
	_anim_from = from
	_anim_to = to
	_anim_piece = p
	_anim_captured = captured
	_anim_is_capture = captured != 0
	_anim_pos_from = board_to_local(from.x, from.y)
	_anim_pos_to = board_to_local(to.x, to.y)
	_anim_progress = 0.0
	_anim_capture_alpha = 1.0
	_anim_capture_scale = 1.0
	_anim_capture_fx = 0.0
	# 取消拖拽
	_cancel_drag_silent()
	var dist: float = Vector2(from).distance_to(Vector2(to))
	var dur: float = clamp(0.24 + dist * 0.022, 0.26, 0.50)
	if dist >= 5:
		dur += 0.04
	_anim_tween = create_tween()
	_anim_tween.set_parallel(false)
	_anim_tween.tween_property(self, "_anim_progress", 1.0, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _anim_is_capture:
		var cap_tween := create_tween()
		cap_tween.tween_property(self, "_anim_capture_alpha", 1.0, dur * 0.52)
		cap_tween.tween_property(self, "_anim_capture_alpha", 0.0, dur * 0.40).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		cap_tween.parallel().tween_property(self, "_anim_capture_scale", 0.68, dur * 0.40).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		var fx_tween := create_tween()
		fx_tween.tween_interval(dur * 0.08)
		fx_tween.tween_property(self, "_anim_capture_fx", 1.0, dur * 0.34).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		fx_tween.tween_property(self, "_anim_capture_fx", 0.0, dur * 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_anim_tween.tween_callback(func() -> void:
			_anim_from = Vector2i(-1, -1)
			_anim_to = Vector2i(-1, -1)
			_anim_piece = 0
			_anim_captured = 0
			_anim_is_capture = false
			_anim_progress = 0.0
			_anim_capture_alpha = 1.0
			_anim_capture_scale = 1.0
			_anim_capture_fx = 0.0
			queue_redraw()
		)
	else:
		_anim_tween.tween_callback(func() -> void:
			_anim_from = Vector2i(-1, -1)
			_anim_to = Vector2i(-1, -1)
			_anim_piece = 0
			_anim_progress = 0.0
			queue_redraw()
		)
	queue_redraw()
	_try_haptic(16)

func is_animating() -> bool:
	return _anim_piece != 0

func board_to_local(bx: int, by: int) -> Vector2:
	return Vector2(_origin.x + bx * _cell, _origin.y + by * _cell)

func local_to_board(p: Vector2) -> Vector2i:
	return Vector2i(int(round((p.x - _origin.x) / _cell)), int(round((p.y - _origin.y) / _cell)))

# ── 长按拖拽 ─────────────────────────────────────────────
func _enter_drag() -> void:
	if _drag_from.x == -1 or _is_dragging:
		return
	_is_dragging = true
	_pending_drag = false
	_drag_pos = _touch_down_pos
	queue_redraw()
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_pickup"):
		am.call("play_pickup")
	_try_haptic(14)

func _cancel_drag_silent() -> void:
	_is_dragging = false
	_pending_drag = false
	_drag_from = Vector2i(-1, -1)
	_long_press_time = 0.0
	_pending_pos = Vector2i(-1, -1)

func _do_bounce_back() -> void:
	# 非法落点：弹性回弹到起点 + 震动 + 音效
	var start: Vector2 = board_to_local(_drag_from.x, _drag_from.y)
	var from: Vector2i = _drag_from
	_is_dragging = false
	_pending_drag = false
	# 用 tween 做回弹
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_drag_pos = _drag_pos # 当前手指处
	_bounce_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_bounce_tween.tween_property(self, "_drag_pos", start, 0.28)
	_bounce_tween.tween_callback(func() -> void:
		_drag_from = Vector2i(-1, -1)
		_long_press_time = 0.0
		queue_redraw()
	)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_bounce_back"):
			am.call("play_bounce_back")
		elif am.has_method("play_invalid"):
			am.call("play_invalid")
	_try_haptic(36)
	queue_redraw()

# ── 输入 ─────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if not interactable or _anim_piece != 0:
		# 飞行时屏蔽输入
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			accept_event()
		return

	# 触屏按下
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_touch_down_pos = st.position
			_drag_start_pos = st.position
			var pos: Vector2i = local_to_board(st.position)
			if not XiangqiLogic.inside_board(pos.x, pos.y):
				return
			var piece: int = board[pos.y][pos.x] if pos.y >= 0 and pos.y < 10 and pos.x >= 0 and pos.x < 9 else 0
			# 若已选中同色棋，准备拖拽
			if selected.x != -1 and pos == selected and piece != 0:
				_drag_from = pos
				_pending_drag = true
				_long_press_time = 0.0
				_pending_pos = pos
				# 立即高亮，不等待长按（给即时反馈）
				queue_redraw()
			elif piece != 0:
				# 选中新棋，同时准备长按拖拽
				square_selected.emit(pos)
				var am2: Node = get_node_or_null("/root/AudioManager")
				if am2 != null and am2.has_method("play_select"):
					am2.call("play_select")
				_drag_from = pos
				_pending_drag = true
				_long_press_time = 0.0
				_pending_pos = pos
				_try_haptic(10)
			else:
				# 点空地：若已选中则尝试走子（点击走子兼容）
				if selected.x != -1:
					for t in legal_targets:
						if t == pos:
							try_move.emit(selected, pos)
							_drag_from = Vector2i(-1, -1)
							_pending_drag = false
							queue_redraw()
							accept_event()
							return
					# 点空地取消选中
					square_selected.emit(Vector2i(-1, -1))
			accept_event()
		else:
			# 抬起
			var release_pos: Vector2 = st.position
			if _is_dragging and _drag_from.x != -1:
				var drop: Vector2i = local_to_board(release_pos)
				var valid: bool = false
				if XiangqiLogic.inside_board(drop.x, drop.y):
					for t in legal_targets:
						if t == drop:
							valid = true
							break
				if valid:
					# 成功落子：保留 drag_from 直到飞行开始（animate_move 会清除）
					var from_copy: Vector2i = _drag_from
					_is_dragging = false
					_pending_drag = false
					_drag_from = Vector2i(-1, -1)
					_long_press_time = 0.0
					try_move.emit(from_copy, drop)
				else:
					_do_bounce_back()
				accept_event()
				return
			# 非拖拽的短按抬起：若按住时间短且移动小，视为点击（已在按下时处理选中/走子）
			# 若 pending 但未进入 dragging，取消 pending 并视为点击完成
			if _pending_drag:
				# 轻点未长按：保持选中状态，不回弹
				_pending_drag = false
				_long_press_time = 0.0
				# _drag_from 保留为选中，便于点击走子
				if _is_dragging:
					_is_dragging = false
			queue_redraw()
			accept_event()
		return

	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _drag_from.x == -1:
			return
		var moved: float = sd.position.distance_to(_drag_start_pos)
		if _pending_drag and not _is_dragging:
			if moved > 14:
				# 轻微移动即进入拖拽（无需等长按）—— 更顺手
				if moved > _drag_threshold:
					_enter_drag()
				_drag_pos = sd.position
				queue_redraw()
				accept_event()
				return
			# 未超时但位置微动，保持 pending
		if _is_dragging:
			_drag_pos = sd.position
			queue_redraw()
			accept_event()
		elif _pending_drag:
			_drag_pos = sd.position
		return

	# 鼠标（桌面/模拟器）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_touch_down_pos = event.position
		_drag_start_pos = event.position
		var pos2: Vector2i = local_to_board(event.position)
		if not XiangqiLogic.inside_board(pos2.x, pos2.y):
			return
		# 选中态下点合法落点直接走子
		if selected.x != -1:
			for t in legal_targets:
				if t == pos2:
					try_move.emit(selected, pos2)
					var am3: Node = get_node_or_null("/root/AudioManager")
					if am3 != null and am3.has_method("play_select"):
						am3.call("play_select")
					return
		var p2: int = board[pos2.y][pos2.x] if pos2.y >= 0 and pos2.y < 10 and pos2.x >= 0 and pos2.x < 9 else 0
		if p2 != 0:
			square_selected.emit(pos2)
			_drag_from = pos2
			_pending_drag = true
			_long_press_time = 0.0
			_is_dragging = false
			var am4: Node = get_node_or_null("/root/AudioManager")
			if am4 != null and am4.has_method("play_select"):
				am4.call("play_select")
			_try_haptic(10)
		else:
			square_selected.emit(Vector2i(-1, -1))
			_drag_from = Vector2i(-1, -1)
		accept_event()
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_dragging and _drag_from.x != -1:
			var drop2: Vector2i = local_to_board(event.position)
			var ok: bool = false
			for t in legal_targets:
				if t == drop2:
					ok = true
					break
			if ok:
				var fc: Vector2i = _drag_from
				_is_dragging = false
				_pending_drag = false
				_drag_from = Vector2i(-1, -1)
				try_move.emit(fc, drop2)
			else:
				_do_bounce_back()
			accept_event()
			return
		# 抬起时若 pending，取消
		if _pending_drag:
			_pending_drag = false
			_long_press_time = 0.0
		return

	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _drag_from.x == -1:
			return
		var mp: Vector2 = event.position
		if not _is_dragging and _pending_drag:
			if mp.distance_to(_drag_start_pos) > _drag_threshold:
				_enter_drag()
		if _is_dragging:
			_drag_pos = mp
			queue_redraw()
			accept_event()

func _try_haptic(ms: int) -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() in ["Android", "iOS"]:
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(ms)

# ── 绘制 ─────────────────────────────────────────────────
func _draw_attack_motion(center: Vector2, typ: int, is_red: bool, alpha: float, sc: float, motion_t: float) -> void:
	# 吃子专属出招层：攻击方向沿实际飞行方向。
	var u: float = _cell * sc
	var travel: Vector2 = (_anim_pos_to - _anim_pos_from).normalized()
	if travel.length_squared() < 0.01:
		travel = Vector2.RIGHT
	var side := Vector2(-travel.y, travel.x)
	var strike: float = sin(clamp((motion_t - 0.12) / 0.70, 0.0, 1.0) * PI)
	var base_col: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	var slash := Color(ApplePalette.GOLD_BRIGHT.r, ApplePalette.GOLD_BRIGHT.g, ApplePalette.GOLD_BRIGHT.b, 0.90 * alpha * strike)
	var glow := Color(base_col.r, base_col.g, base_col.b, 0.60 * alpha * strike)
	var width: float = max(1.4, u * 0.030)
	match typ:
		XiangqiLogic.HORSE:
			# 马冲锋：三道速度线和前方马首光弧。
			for i in range(3):
				var back := center - travel * (u * (0.26 + i * 0.10)) + side * (u * (i - 1) * 0.07)
				draw_line(back, back - travel * u * (0.16 + strike * 0.10), slash, width)
			draw_arc(center + travel * u * 0.15, u * (0.16 + strike * 0.10), -0.9, 0.9, 18, glow, width)
		XiangqiLogic.CHARIOT:
			# 车撞击：车头楔形和碰撞金环。
			var nose := center + travel * u * (0.20 + strike * 0.20)
			draw_line(nose - side * u * 0.18, nose + travel * u * 0.12, slash, width * 1.4)
			draw_line(nose + side * u * 0.18, nose + travel * u * 0.12, slash, width * 1.4)
			draw_arc(nose + travel * u * 0.05, u * (0.08 + strike * 0.12), 0, TAU, 24, slash, width)
		XiangqiLogic.CANNON:
			# 炮击：炮口十字闪焰和后方烟迹。
			var muzzle := center + travel * u * 0.24
			var flash_len: float = u * (0.16 + strike * 0.16)
			draw_line(muzzle - travel * flash_len, muzzle + travel * flash_len, slash, width * 1.8)
			draw_line(muzzle - side * flash_len, muzzle + side * flash_len, slash, width * 1.4)
			for i in range(3):
				var smoke_pos := muzzle - travel * u * (0.12 + i * 0.07) + side * u * (i - 1) * 0.06
				draw_circle(smoke_pos, u * (0.035 + strike * 0.02), Color(0.30, 0.25, 0.18, 0.22 * alpha * strike))
		XiangqiLogic.ELEPHANT:
			# 象突：两根象牙和沉重冲击纹。
			var tusk_base := center + travel * u * 0.08
			draw_line(tusk_base + side * u * 0.10, tusk_base + travel * u * (0.25 + strike * 0.16) + side * u * 0.04, slash, width)
			draw_line(tusk_base - side * u * 0.10, tusk_base + travel * u * (0.25 + strike * 0.16) - side * u * 0.04, slash, width)
			draw_arc(center + travel * u * 0.18, u * (0.14 + strike * 0.08), -1.2, 1.2, 16, glow, width)
		XiangqiLogic.KING:
			# 将帅爆发：冠顶向命中方向释放扇形光束。
			var crown := center - travel * u * 0.08
			for i in range(3):
				var beam_start := crown + side * u * (i - 1) * 0.09
				draw_line(beam_start, beam_start + travel * u * (0.22 + strike * 0.18), slash, width)
			draw_circle(crown, u * (0.06 + strike * 0.06), slash)
		XiangqiLogic.ADVISOR:
			# 士仕挥剑：两段交错剑光。
			var slash_center := center + travel * u * 0.10
			draw_line(slash_center - side * u * 0.24 - travel * u * 0.12, slash_center + side * u * 0.24 + travel * u * 0.12, slash, width * 1.5)
			draw_line(slash_center - side * u * 0.18 + travel * u * 0.04, slash_center + side * u * 0.18 + travel * u * 0.20, glow, width)
		XiangqiLogic.PAWN:
			# 兵卒刺枪：枪尖向前伸出并在命中处爆亮。
			var spear_base := center - travel * u * 0.10
			var spear_tip := center + travel * u * (0.24 + strike * 0.18)
			draw_line(spear_base, spear_tip, slash, width * 1.3)
			draw_line(spear_tip - side * u * 0.08, spear_tip + side * u * 0.08, slash, width)
			draw_circle(spear_tip, u * (0.025 + strike * 0.045), slash)

func _draw() -> void:
	# ── 天天象棋暖木棋院质感 ─────────────────────────────────
	var outer := Rect2(Vector2.ZERO, size)
	var r_outer: float = clamp(_cell * 0.32, 10, 14) # TianTian 木框更方正，不过度圆角
	# 深胡桃木外框
	_draw_rounded_rect(outer, r_outer, ApplePalette.BOARD_FRAME)
	# 木框内侧黄铜细线 + 顶部高光（棋院灯光）
	_draw_rounded_rect_outline(outer.grow(-1), r_outer, ApplePalette.BOARD_FRAME_HIGHLIGHT, 1.2)
	draw_line(Vector2(_frame_thick, _frame_thick - 4), Vector2(size.x - _frame_thick, _frame_thick - 4), Color("#E8C9A0", 0.18), 1.0)
	# 木纹肌理：横向细腻木纹噪点（用低 alpha 直线模拟真实木纹）
	var wood_mid: Color = ApplePalette.BOARD_WOOD_MID
	for wy in range(9):
		var wy_pos: float = outer.position.y + outer.size.y * (0.08 + wy * 0.11)
		var wa: float = 0.06 + fmod(wy * 0.37, 0.04)
		draw_line(Vector2(outer.position.x + 8, wy_pos), Vector2(outer.position.x + outer.size.x - 8, wy_pos + 0.8), Color(wood_mid.r, wood_mid.g, wood_mid.b, wa), 1.0)
		# 第二层斜纹
		if wy % 2 == 0:
			draw_line(Vector2(outer.position.x + 16, wy_pos + 3), Vector2(outer.position.x + outer.size.x - 16, wy_pos + 3.6), Color(ApplePalette.BOARD_WOOD_LIGHT.r, ApplePalette.BOARD_WOOD_LIGHT.g, ApplePalette.BOARD_WOOD_LIGHT.b, 0.05), 1.0)
	# 米黄宣纸棋面 — 像天天象棋的纸面，暖而干净
	var paper := Rect2(Vector2(_frame_thick, _frame_thick), size - Vector2(_frame_thick * 2, _frame_thick * 2))
	_draw_rounded_rect(paper, r_outer - 4, ApplePalette.BOARD_PAPER)
	# 纸面细微横纹 + 顶部压线
	var paper_grain: Color = Color("#8B5A2B", 0.045)
	for gy in range(6):
		var yy: float = paper.position.y + paper.size.y * (0.14 + gy * 0.13)
		draw_line(Vector2(paper.position.x + 14, yy), Vector2(paper.position.x + paper.size.x - 14, yy + 0.6), paper_grain, 1.0)
	draw_line(paper.position + Vector2(6, 1), paper.position + Vector2(paper.size.x - 6, 1), Color("#000000", 0.06), 1.0)
	draw_line(paper.position + Vector2(1, 6), paper.position + Vector2(1, paper.size.y - 6), Color("#FFFFFF", 0.35), 1.0) # 左侧纸张高光

	# 网格
	var river_top: float = _origin.y + 4 * _cell
	var river_bot: float = _origin.y + 5 * _cell
	var river_rect := Rect2(Vector2(_origin.x - 10, river_top), Vector2(8 * _cell + 20, river_bot - river_top))
	draw_rect(river_rect, ApplePalette.BOARD_RIVER_TINT)
	var line_col: Color = ApplePalette.BOARD_LINE
	var line_soft: Color = ApplePalette.BOARD_LINE_SOFT
	for y in range(10):
		var yy2: float = _origin.y + y * _cell
		draw_line(Vector2(_origin.x, yy2), Vector2(_origin.x + 8 * _cell, yy2), line_col, 1.4 if y == 0 or y == 9 else 1.1)
	for x in range(9):
		var xx: float = _origin.x + x * _cell
		if x == 0 or x == 8:
			draw_line(Vector2(xx, _origin.y), Vector2(xx, _origin.y + 9 * _cell), line_col, 1.4)
		else:
			draw_line(Vector2(xx, _origin.y), Vector2(xx, river_top), line_soft, 1.1)
			draw_line(Vector2(xx, river_bot), Vector2(xx, _origin.y + 9 * _cell), line_soft, 1.1)
	var palace_col: Color = Color("#2B1E0F", 0.68)
	for seg in [[Vector2i(3, 0), Vector2i(5, 2)], [Vector2i(5, 0), Vector2i(3, 2)], [Vector2i(3, 7), Vector2i(5, 9)], [Vector2i(5, 7), Vector2i(3, 9)]]:
		var a: Vector2 = board_to_local(seg[0].x, seg[0].y)
		var b2: Vector2 = board_to_local(seg[1].x, seg[1].y)
		draw_line(a, b2, palace_col, 1.4)
	# 隹角标
	for p in [[0, 2], [2, 2], [6, 2], [8, 2], [0, 7], [2, 7], [6, 7], [8, 7], [1, 3], [7, 3]]:
		_draw_corner_marks(p[0], p[1])
	var font: Font = ThemeDB.fallback_font
	var river_fs: int = int(clamp(_cell * 0.32, 13, 20))
	draw_string(font, Vector2(_origin.x + 1.15 * _cell, (river_top + river_bot) / 2 + 6), "楚  河", HORIZONTAL_ALIGNMENT_LEFT, -1, river_fs, ApplePalette.BOARD_RIVER_INK)
	draw_string(font, Vector2(_origin.x + 5.05 * _cell, (river_top + river_bot) / 2 + 6), "汉  界", HORIZONTAL_ALIGNMENT_LEFT, -1, river_fs, ApplePalette.BOARD_RIVER_INK)
	draw_string(font, Vector2(_origin.x + 3.85 * _cell, (river_top + river_bot) / 2 + 4), "·", HORIZONTAL_ALIGNMENT_LEFT, -1, int(river_fs * 0.70), Color("#2B1E0F", 0.24))

	# 上一步淡化
	var last_alpha: float = 1.0 - _anim_progress * 0.55 if _anim_piece != 0 else 1.0
	if last_move_from.x != -1:
		_highlight_square(last_move_from, Color(ApplePalette.BOARD_LAST_MOVE.r, ApplePalette.BOARD_LAST_MOVE.g, ApplePalette.BOARD_LAST_MOVE.b, 0.42 * last_alpha), 10)
	if last_move_to.x != -1 and not (_anim_piece != 0 and _anim_to == last_move_to):
		_highlight_square(last_move_to, Color(ApplePalette.BOARD_LAST_MOVE.r, ApplePalette.BOARD_LAST_MOVE.g, ApplePalette.BOARD_LAST_MOVE.b, 0.52 * last_alpha), 10)
	# 选中高光：拖拽中隐藏原位高光，改为拖拽态
	if selected.x != -1 and not (_is_dragging and selected == _drag_from):
		_highlight_square(selected, Color(ApplePalette.BOARD_LAST_MOVE.r, ApplePalette.BOARD_LAST_MOVE.g, ApplePalette.BOARD_LAST_MOVE.b, 0.55), 10)
		_draw_square_ring(selected, ApplePalette.BOARD_SELECT_RING, 2.4, 10)
		_draw_square_ring(selected, Color(ApplePalette.BOARD_SELECT_RING.r, ApplePalette.BOARD_SELECT_RING.g, ApplePalette.BOARD_SELECT_RING.b, 0.20), 7.0, 10)
	# 合法落点 — 手机端超大、脉冲、带标签
	for t in legal_targets:
		var c: Vector2 = board_to_local(t.x, t.y)
		var is_capture: bool = false
		if t.y >= 0 and t.y < 10 and t.x >= 0 and t.x < 9 and not board.is_empty():
			is_capture = board[t.y][t.x] != 0
		# 脉冲缩放 1.0..1.12
		var pulse: float = 1.0 + sin(_pulse_t * 3.0) * 0.08
		var dragging_dim: float = 0.96 if _is_dragging else 1.0
		if is_capture:
			# 天天象棋吃子：朱红粗环 + 暖金内环，跳动提示可吃
			var r_out: float = (20 + sin(_pulse_t * 4.0) * 1.0) * (_cell / 52.0)
			draw_arc(c, r_out, 0, TAU, 32, Color(ApplePalette.DANGER.r, ApplePalette.DANGER.g, ApplePalette.DANGER.b, 0.92 * dragging_dim), 3.2)
			draw_arc(c, r_out - 3.5, 0, TAU, 32, Color(ApplePalette.GOLD.r, ApplePalette.GOLD.g, ApplePalette.GOLD.b, 0.45), 1.1)
			draw_circle(c, 6 * (_cell / 52.0), Color(ApplePalette.DANGER.r, ApplePalette.DANGER.g, ApplePalette.DANGER.b, 0.16))
		else:
			# 天天象棋落点：翡翠绿实心 + 白芯，像天天象棋的小绿点，拖拽时更亮
			var s: float = (_cell / 52.0) * pulse
			var base_r: float = 11 if _is_dragging else 9
			var inner_r: float = 4.8 if _is_dragging else 3.6
			var halo_r: float = base_r + 4 if _is_dragging else base_r + 2
			draw_circle(c, halo_r * s, Color(ApplePalette.TEAL.r, ApplePalette.TEAL.g, ApplePalette.TEAL.b, 0.16 if _is_dragging else 0.08))
			draw_circle(c, base_r * s, Color(ApplePalette.TEAL.r, ApplePalette.TEAL.g, ApplePalette.TEAL.b, 0.18 * dragging_dim))
			draw_circle(c, (base_r - 1.8) * s, ApplePalette.TEAL)
			draw_circle(c, inner_r * s, Color.WHITE)
			if _is_dragging:
				draw_arc(c, base_r * s, 0, TAU, 24, Color.WHITE, 0.9)

	if board.is_empty():
		return

	# 静止棋：飞行/拖拽期间隐藏源与目标
	for y in range(10):
		for x in range(9):
			var p: int = board[y][x]
			if p == 0:
				continue
			var cur: Vector2i = Vector2i(x, y)
			if _anim_piece != 0:
				if cur == _anim_from or cur == _anim_to:
					continue
			if _is_dragging and cur == _drag_from:
				continue
			_draw_piece(board_to_local(x, y), p, font, 1.0, 1.0, 0.0)

	# 被吃子消散
	if _anim_is_capture and _anim_captured != 0 and _anim_progress > 0.0:
		var cap_pos: Vector2 = board_to_local(_anim_to.x, _anim_to.y)
		var lift: float = -8 * ease(_anim_progress, 0.45)
		_draw_piece(cap_pos + Vector2(0, lift), _anim_captured, font, _anim_capture_alpha, _anim_capture_scale, 0.0)
		if _anim_capture_fx > 0.0:
			_draw_capture_effect(cap_pos, _anim_capture_fx)

	# 飞行棋 — 抛物线 + 缩放 + 阴影
	if _anim_piece != 0 and _anim_from.x != -1 and _anim_to.x != -1 and _anim_progress > 0.0:
		var t: float = _anim_progress
		var fly: Vector2 = _anim_pos_from.lerp(_anim_pos_to, t)
		var dist2: float = _anim_pos_from.distance_to(_anim_pos_to)
		var lift_h: float = clamp(dist2 * 0.13, 12, 32)
		fly.y -= sin(t * PI) * lift_h
		var scale: float = 1.0 + sin(t * PI) * 0.10
		var shadow_alpha: float = lerp(0.28, 0.08, sin(t * PI))
		var lift_for_shadow: float = sin(t * PI) * lift_h
		var ground: Vector2 = _anim_pos_from.lerp(_anim_pos_to, t)
		_draw_piece_shadow(ground + Vector2(0, 3 + lift_for_shadow * 0.18), shadow_alpha)
		_draw_piece(fly, _anim_piece, font, 1.0, scale, lift_for_shadow, t)

	# 拖拽棋 — 手指上方悬浮，放大+投影+轨迹虚影
	if _is_dragging and _drag_from.x != -1:
		var drag_piece: int = 0
		if _drag_from.y >= 0 and _drag_from.y < 10 and _drag_from.x >= 0 and _drag_from.x < 9:
			drag_piece = board[_drag_from.y][_drag_from.x]
		if drag_piece == 0 and _anim_piece != 0 and _drag_from == _anim_from:
			drag_piece = _anim_piece
		if drag_piece != 0:
			# 轨迹虚影：起点到手指的淡线
			var src: Vector2 = board_to_local(_drag_from.x, _drag_from.y)
			draw_dashed_line(src, _drag_pos + Vector2(0, -30), Color("#D4A574", 0.22), 2.0, 6.0)
			_draw_piece_shadow(_drag_pos + Vector2(0, 10), 0.20)
			_draw_piece(_drag_pos + Vector2(0, -30), drag_piece, font, 1.0, 1.14, 18)
			# 手指处白点
			draw_circle(_drag_pos, 4, Color.WHITE)
			draw_circle(_drag_pos, 6, Color("#D4A574", 0.35))
	# 未进入拖拽但 pending：起点轻微上浮提示可拖动
	elif _pending_drag and _drag_from.x != -1 and not _is_dragging:
		# 给一点点呼吸提示
		pass

	# 拖拽时的 bounce 回弹：用 _drag_pos 绘制悬浮棋，_bounce_tween 会自动插值
	if _bounce_tween and _bounce_tween.is_valid() and _drag_from.x != -1:
		# 由 _drag_pos  tween 驱动，已在拖拽分支处理，回弹时 _is_dragging 已 false，此分支单独画
		var bp: int = board[_drag_from.y][_drag_from.x] if _drag_from.y >= 0 and _drag_from.y < 10 and _drag_from.x >= 0 and _drag_from.x < 9 else 0
		if bp != 0:
			_draw_piece_shadow(_drag_pos + Vector2(0, 8), 0.16)
			_draw_piece(_drag_pos + Vector2(0, -8), bp, font, 1.0, 1.04, 6)

func _draw_piece_shadow(center: Vector2, alpha: float) -> void:
	draw_circle(center, _cell * 0.42, Color("#000000", alpha * 0.55))
	draw_circle(center + Vector2(2, 1), _cell * 0.28, Color("#000000", alpha * 0.22))

func _draw_corner_marks(bx: int, by: int) -> void:
	var c: Vector2 = board_to_local(bx, by)
	var s: float = clamp(_cell * 0.14, 7, 10)
	var gap: float = clamp(_cell * 0.07, 3.5, 5)
	var col: Color = Color("#2B1E0F", 0.40)
	var dirs: Array = [[-1, -1], [1, -1], [-1, 1], [1, 1]]
	for d in dirs:
		var dx: int = d[0]; var dy: int = d[1]
		var px: float = c.x + dx * gap
		var py: float = c.y + dy * gap
		draw_line(Vector2(px, py), Vector2(px + dx * s, py), col, 1.2)
		draw_line(Vector2(px, py), Vector2(px, py + dy * s), col, 1.2)

func _draw_piece(center: Vector2, p: int, font: Font, alpha: float = 1.0, scale: float = 1.0, lift: float = 0.0, motion_t: float = 0.0) -> void:
	var is_red: bool = p > 0
	var r: float = _cell * 0.46 * scale
	var r_in: float = _cell * 0.39 * scale
	if lift == 0.0 and scale == 1.0:
		draw_circle(center + Vector2(0, 3), r, Color("#000000", 0.24 * alpha))
		draw_circle(center + Vector2(0, 1.2), r, Color("#000000", 0.10 * alpha))
	var ring_col: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	var ring_highlight: Color = Color("#E8A87A") if is_red else Color("#5A5A60")
	ring_col.a *= alpha
	ring_highlight.a *= alpha
	draw_circle(center, r, ring_col)
	draw_arc(center + Vector2(-0.6 * scale, -0.8 * scale), r - 1 * scale, 1.15 * PI, 1.85 * PI, 20, ring_highlight, 1.3 * scale)
	var inlay: Color = ApplePalette.PIECE_RED_INLAY if is_red else ApplePalette.PIECE_BLACK_INLAY
	inlay.a *= alpha
	draw_circle(center, r_in, inlay)
	var gold: Color = ApplePalette.PIECE_GOLD_RING
	gold.a *= alpha
	draw_arc(center, r_in, 0, TAU, 32, gold, 1.0 * scale)
	draw_arc(center, r * 0.78, 0, TAU, 32, Color("#000000", 0.05 * alpha), 1.0 * scale)
	draw_circle(center + Vector2(-_cell * 0.10, -_cell * 0.12), _cell * 0.10, Color("#FFFFFF", 0.09 * alpha))
	# 独立兵种 2.5D 角色：中文棋字保留识别度，角色轮廓提供战斗辨识度。
	_draw_piece_character_3d(center, XiangqiLogic.piece_type(p), is_red, alpha, scale, motion_t)
	var label: String = _piece_label(p)
	var fs: int = int(_cell * 0.42 * scale)
	if fs < 13:
		fs = 13
	var disc: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	disc.a *= alpha
	var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var base: Vector2 = center - Vector2(ts.x / 2, -ts.y / 3.0)
	draw_string(font, base + Vector2(0, 1 * scale), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color("#000000", 0.16 * alpha))
	draw_string(font, base, label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, disc)

func _draw_3d_poly(points: PackedVector2Array, depth: float, top: Color, side: Color, outline: Color, width: float) -> void:
	if points.size() < 3:
		return
	var lower := PackedVector2Array()
	for point in points:
		lower.append(point + Vector2(0, depth))
	var lower_line := lower.duplicate()
	lower_line.append(lower[0])
	draw_colored_polygon(lower, side)
	draw_polyline(lower_line, outline, width)
	var top_line := points.duplicate()
	top_line.append(points[0])
	draw_colored_polygon(points, top)
	draw_polyline(top_line, outline, width)

func _draw_piece_character_3d(center: Vector2, typ: int, is_red: bool, alpha: float, sc: float, motion_t: float = 0.0) -> void:
	var u: float = _cell * sc
	var base_col: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	var top_col := Color(base_col.r * 0.72 + 0.28, base_col.g * 0.72 + 0.28, base_col.b * 0.72 + 0.28, 0.86 * alpha)
	var side_col := Color(base_col.r * 0.42, base_col.g * 0.42, base_col.b * 0.42, 0.90 * alpha)
	var outline := Color("#24180F", 0.84 * alpha)
	var gold := Color(ApplePalette.GOLD_BRIGHT.r, ApplePalette.GOLD_BRIGHT.g, ApplePalette.GOLD_BRIGHT.b, 0.80 * alpha)
	var width: float = max(1.2, u * 0.028)
	var depth: float = u * 0.075
	match typ:
		XiangqiLogic.KING:
			# 将/帅：披甲躯干 + 王冠，顶部高光和底部厚度形成小型雕像感。
			var torso := PackedVector2Array([
				center + Vector2(-u * 0.22, u * 0.27),
				center + Vector2(-u * 0.18, -u * 0.05),
				center + Vector2(-u * 0.12, -u * 0.18),
				center + Vector2(u * 0.12, -u * 0.18),
				center + Vector2(u * 0.18, -u * 0.05),
				center + Vector2(u * 0.22, u * 0.27),
			])
			_draw_3d_poly(torso, depth, top_col, side_col, outline, width)
			var crown := PackedVector2Array([
				center + Vector2(-u * 0.17, -u * 0.12),
				center + Vector2(-u * 0.16, -u * 0.31),
				center + Vector2(-u * 0.06, -u * 0.23),
				center + Vector2(0, -u * 0.34),
				center + Vector2(u * 0.07, -u * 0.23),
				center + Vector2(u * 0.17, -u * 0.31),
				center + Vector2(u * 0.16, -u * 0.12),
			])
			_draw_3d_poly(crown, depth * 0.6, gold, side_col, outline, width)
			draw_line(center + Vector2(-u * 0.15, u * 0.08), center + Vector2(u * 0.15, u * 0.08), gold, width)
		XiangqiLogic.ADVISOR:
			# 士/仕：肩甲、护卫披风和向上出鞘的剑。
			var cape := PackedVector2Array([
				center + Vector2(-u * 0.23, u * 0.27),
				center + Vector2(-u * 0.16, -u * 0.08),
				center + Vector2(0, -u * 0.20),
				center + Vector2(u * 0.16, -u * 0.08),
				center + Vector2(u * 0.23, u * 0.27),
			])
			_draw_3d_poly(cape, depth, top_col, side_col, outline, width)
			draw_line(center + Vector2(0, -u * 0.29), center + Vector2(0, u * 0.13), gold, width * 1.2)
			draw_line(center + Vector2(-u * 0.13, -u * 0.08), center + Vector2(u * 0.13, -u * 0.08), gold, width)
			draw_circle(center + Vector2(0, -u * 0.29), u * 0.035, gold)
		XiangqiLogic.ELEPHANT:
			# 象/相：大耳、额头、象牙和下垂鼻梁。
			var head := PackedVector2Array([
				center + Vector2(-u * 0.20, u * 0.22),
				center + Vector2(-u * 0.19, -u * 0.06),
				center + Vector2(-u * 0.12, -u * 0.22),
				center + Vector2(u * 0.09, -u * 0.23),
				center + Vector2(u * 0.20, -u * 0.05),
				center + Vector2(u * 0.18, u * 0.22),
			])
			_draw_3d_poly(head, depth, top_col, side_col, outline, width)
			draw_arc(center + Vector2(-u * 0.15, -u * 0.04), u * 0.17, 0.6, 5.3, 20, gold, width)
			draw_line(center + Vector2(u * 0.08, -u * 0.02), center + Vector2(u * 0.14, u * 0.25), gold, width)
			draw_line(center + Vector2(u * 0.14, u * 0.25), center + Vector2(u * 0.04, u * 0.29), gold, width)
			draw_circle(center + Vector2(u * 0.08, -u * 0.10), u * 0.026, outline)
		XiangqiLogic.HORSE:
			# 马：独立烈马头、立耳、鼻梁、鬃毛与高光眼睛。
			var horse := PackedVector2Array([
				center + Vector2(-u * 0.20, u * 0.28),
				center + Vector2(-u * 0.18, -u * 0.05),
				center + Vector2(-u * 0.10, -u * 0.27),
				center + Vector2(-u * 0.02, -u * 0.15),
				center + Vector2(u * 0.07, -u * 0.32),
				center + Vector2(u * 0.14, -u * 0.12),
				center + Vector2(u * 0.24, u * 0.04),
				center + Vector2(u * 0.16, u * 0.18),
				center + Vector2(u * 0.08, u * 0.28),
			])
			_draw_3d_poly(horse, depth, top_col, side_col, outline, width)
			draw_line(center + Vector2(-u * 0.12, -u * 0.23), center + Vector2(-u * 0.29, -u * 0.05), gold, width)
			draw_line(center + Vector2(-u * 0.04, -u * 0.19), center + Vector2(-u * 0.15, u * 0.21), side_col, width * 1.2)
			draw_circle(center + Vector2(u * 0.10, -u * 0.08), u * 0.035, gold)
			draw_circle(center + Vector2(u * 0.10, -u * 0.08), u * 0.014, outline)
		XiangqiLogic.CHARIOT:
			# 車：战车城垛、车厢、双轮与顶部旗片。
			var tower := PackedVector2Array([
				center + Vector2(-u * 0.23, u * 0.23),
				center + Vector2(-u * 0.22, -u * 0.14),
				center + Vector2(-u * 0.13, -u * 0.14),
				center + Vector2(-u * 0.13, -u * 0.25),
				center + Vector2(-u * 0.04, -u * 0.25),
				center + Vector2(-u * 0.04, -u * 0.14),
				center + Vector2(u * 0.06, -u * 0.14),
				center + Vector2(u * 0.06, -u * 0.25),
				center + Vector2(u * 0.16, -u * 0.25),
				center + Vector2(u * 0.17, u * 0.23),
			])
			_draw_3d_poly(tower, depth, top_col, side_col, outline, width)
			draw_circle(center + Vector2(-u * 0.15, u * 0.22), u * 0.10, side_col)
			draw_circle(center + Vector2(-u * 0.15, u * 0.22), u * 0.07, gold, false, width)
			draw_circle(center + Vector2(u * 0.15, u * 0.22), u * 0.10, side_col)
			draw_circle(center + Vector2(u * 0.15, u * 0.22), u * 0.07, gold, false, width)
			draw_line(center + Vector2(0, -u * 0.25), center + Vector2(0, -u * 0.36), gold, width)
		XiangqiLogic.CANNON:
			# 炮/砲：厚炮架、长炮管、炮口环与金属闪光。
			var carriage := PackedVector2Array([
				center + Vector2(-u * 0.24, u * 0.23),
				center + Vector2(-u * 0.17, -u * 0.03),
				center + Vector2(u * 0.16, -u * 0.03),
				center + Vector2(u * 0.24, u * 0.23),
			])
			_draw_3d_poly(carriage, depth, top_col, side_col, outline, width)
			draw_line(center + Vector2(-u * 0.18, -u * 0.02), center + Vector2(u * 0.18, -u * 0.23), gold, width * 2.0)
			draw_circle(center + Vector2(u * 0.20, -u * 0.25), u * 0.075, side_col)
			draw_arc(center + Vector2(u * 0.20, -u * 0.25), u * 0.075, 0, TAU, 20, gold, width)
			draw_line(center + Vector2(-u * 0.12, u * 0.12), center + Vector2(u * 0.12, u * 0.12), gold, width)
		XiangqiLogic.PAWN:
			# 兵/卒：小型战士、头盔、矛和肩甲。
			var soldier := PackedVector2Array([
				center + Vector2(-u * 0.20, u * 0.27),
				center + Vector2(-u * 0.16, -u * 0.03),
				center + Vector2(-u * 0.12, -u * 0.16),
				center + Vector2(u * 0.12, -u * 0.16),
				center + Vector2(u * 0.16, -u * 0.03),
				center + Vector2(u * 0.20, u * 0.27),
			])
			_draw_3d_poly(soldier, depth, top_col, side_col, outline, width)
			draw_arc(center + Vector2(0, -u * 0.11), u * 0.19, PI, TAU, 20, gold, width)
			draw_line(center + Vector2(0, -u * 0.31), center + Vector2(0, u * 0.16), gold, width)
			draw_line(center + Vector2(-u * 0.17, u * 0.12), center + Vector2(u * 0.17, u * 0.12), gold, width)

	if motion_t > 0.001:
		_draw_piece_motion(center, typ, is_red, alpha, sc, motion_t)
		if _anim_is_capture:
			_draw_attack_motion(center, typ, is_red, alpha, sc, motion_t)

func _draw_piece_motion(center: Vector2, typ: int, is_red: bool, alpha: float, sc: float, motion_t: float) -> void:
	# 只在飞行阶段绘制动作层；静止和拖拽棋子保持干净的角色立姿。
	var u: float = _cell * sc
	var phase: float = motion_t * TAU * 2.2
	var beat: float = sin(phase)
	var beat_alt: float = sin(phase + PI)
	var side_col: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	var action_col := Color(ApplePalette.GOLD_BRIGHT.r, ApplePalette.GOLD_BRIGHT.g, ApplePalette.GOLD_BRIGHT.b, 0.72 * alpha)
	var action_dark := Color(side_col.r, side_col.g, side_col.b, 0.58 * alpha)
	var width: float = max(1.1, u * 0.022)
	match typ:
		XiangqiLogic.HORSE:
			# 奔马：四肢交替摆动、鬃毛后掠、脚下短促残影。
			var leg_a := center + Vector2(-u * 0.13, u * 0.20)
			var leg_b := center + Vector2(u * 0.12, u * 0.20)
			draw_line(leg_a, leg_a + Vector2(-u * 0.13, u * (0.13 + beat * 0.07)), action_dark, width)
			draw_line(leg_b, leg_b + Vector2(u * 0.13, u * (0.13 + beat_alt * 0.07)), action_dark, width)
			draw_line(leg_a + Vector2(u * 0.04, 0), leg_a + Vector2(u * 0.17, u * (0.11 + beat_alt * 0.07)), action_dark, width)
			draw_line(leg_b + Vector2(-u * 0.04, 0), leg_b + Vector2(-u * 0.17, u * (0.11 + beat * 0.07)), action_dark, width)
			for i in range(3):
				var mane_y: float = -u * (0.20 - i * 0.07)
				draw_line(center + Vector2(-u * 0.10, mane_y), center + Vector2(-u * (0.26 + 0.04 * sin(phase + i)), mane_y + u * 0.05), action_col, width)
			draw_line(center + Vector2(-u * 0.24, u * 0.34), center + Vector2(-u * (0.36 + 0.05 * sin(phase)), u * 0.34), action_col, width)
		XiangqiLogic.CHARIOT:
			# 战车：车轮转动，轮辐角度随移动进度连续旋转。
			var spin: float = motion_t * TAU * 3.0
			for wheel_x in [-u * 0.15, u * 0.15]:
				var wc := center + Vector2(wheel_x, u * 0.22)
				for spoke in range(2):
					var angle: float = spin + spoke * PI * 0.5
					var dir := Vector2(cos(angle), sin(angle))
					draw_line(wc - dir * u * 0.065, wc + dir * u * 0.065, action_col, width)
				draw_circle(wc, u * 0.018, action_col)
		XiangqiLogic.CANNON:
			# 炮：移动中炮架颠簸，炮口出现后坐力圆环与短烟迹。
			var recoil: float = max(0.0, sin(motion_t * PI * 3.0)) * u * 0.09
			var muzzle := center + Vector2(u * 0.20 - recoil, -u * 0.25)
			draw_arc(muzzle, u * (0.08 + recoil / max(u, 1.0)), 0, TAU, 20, action_col, width)
			draw_line(muzzle + Vector2(u * 0.02, 0), muzzle + Vector2(u * (0.14 + recoil / max(u, 1.0)), -u * 0.03), Color(action_col.r, action_col.g, action_col.b, 0.42), width)
			for i in range(3):
				var smoke := muzzle + Vector2(u * (0.14 + i * 0.06), -u * (0.04 + i * 0.06) + beat * u * 0.025)
				draw_circle(smoke, u * (0.025 + i * 0.009), Color(0.42, 0.38, 0.30, 0.20 * alpha))
		XiangqiLogic.ELEPHANT:
			# 象：沉重踏步、耳朵摆动、鼻梁左右摆动。
			var sway: float = beat * u * 0.055
			draw_arc(center + Vector2(sway - u * 0.15, -u * 0.04), u * 0.18, 0.7, 5.4, 18, action_col, width)
			draw_line(center + Vector2(u * 0.10, u * 0.02), center + Vector2(u * 0.15 + sway, u * 0.25), action_dark, width)
			draw_line(center + Vector2(u * 0.15 + sway, u * 0.25), center + Vector2(u * 0.04 + sway, u * 0.29), action_col, width)
			draw_line(center + Vector2(-u * 0.18, u * 0.28), center + Vector2(-u * 0.24, u * 0.34 + beat_alt * u * 0.03), action_dark, width)
		XiangqiLogic.KING:
			# 将/帅：王旗飘动，冠顶在移动中闪耀。
			var flag_wave: float = beat * u * 0.05
			draw_line(center + Vector2(0, -u * 0.30), center + Vector2(0, -u * 0.48), action_dark, width)
			var flag := PackedVector2Array([
				center + Vector2(0, -u * 0.47),
				center + Vector2(u * 0.20 + flag_wave, -u * 0.43),
				center + Vector2(u * 0.12 + flag_wave, -u * 0.33),
				center + Vector2(0, -u * 0.36),
			])
			draw_colored_polygon(flag, action_col)
			draw_circle(center + Vector2(0, -u * 0.34), u * (0.035 + max(0, beat) * 0.018), action_col)
		XiangqiLogic.ADVISOR:
			# 士/仕：护卫步伐和剑锋斜掠，形成短暂光轨。
			var step: float = beat * u * 0.04
			draw_line(center + Vector2(-u * 0.13, u * 0.23), center + Vector2(-u * 0.20 + step, u * 0.33), action_dark, width)
			draw_line(center + Vector2(u * 0.13, u * 0.23), center + Vector2(u * 0.20 - step, u * 0.33), action_dark, width)
			var sword_start := center + Vector2(-u * 0.14, -u * 0.28)
			var sword_end := center + Vector2(u * 0.19 + beat * u * 0.08, -u * 0.42)
			draw_line(sword_start, sword_end, action_col, width * 1.4)
			draw_line(sword_end, sword_end + Vector2(-u * 0.10, u * 0.03), Color(action_col.r, action_col.g, action_col.b, 0.28), width)
		XiangqiLogic.PAWN:
			# 兵/卒：小战士交替踏步，脚下扬起两粒尘光。
			var step_a := center + Vector2(-u * 0.10, u * 0.24)
			var step_b := center + Vector2(u * 0.10, u * 0.24)
			draw_line(step_a, step_a + Vector2(-u * 0.08, u * (0.12 + beat * 0.06)), action_dark, width)
			draw_line(step_b, step_b + Vector2(u * 0.08, u * (0.12 + beat_alt * 0.06)), action_dark, width)
			draw_circle(center + Vector2(-u * 0.23 + beat * u * 0.04, u * 0.34), u * 0.025, Color(action_col.r, action_col.g, action_col.b, 0.45))
			draw_circle(center + Vector2(u * 0.23 + beat_alt * u * 0.04, u * 0.34), u * 0.020, Color(action_col.r, action_col.g, action_col.b, 0.35))

func _draw_piece_emblem(center: Vector2, typ: int, is_red: bool, alpha: float, sc: float) -> void:
	var u: float = _cell * sc
	var side_col: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	var ink := Color(side_col.r, side_col.g, side_col.b, 0.46 * alpha)
	var soft := Color(side_col.r, side_col.g, side_col.b, 0.18 * alpha)
	var line_w: float = max(1.2, u * 0.025)
	match typ:
		XiangqiLogic.KING:
			# 将/帅：王冠与护额
			var crown := PackedVector2Array([
				center + Vector2(-u * 0.18, -u * 0.18),
				center + Vector2(-u * 0.11, -u * 0.31),
				center + Vector2(0, -u * 0.20),
				center + Vector2(u * 0.11, -u * 0.31),
				center + Vector2(u * 0.18, -u * 0.18),
			])
			draw_colored_polygon(crown, soft)
			draw_polyline(crown, ink, line_w)
			draw_line(center + Vector2(-u * 0.22, u * 0.08), center + Vector2(u * 0.22, u * 0.08), ink, line_w)
			draw_circle(center + Vector2(0, -u * 0.24), u * 0.035, ink)
		XiangqiLogic.ADVISOR:
			# 士/仕：宫廷护卫的佩剑与菱形徽章
			draw_line(center + Vector2(0, -u * 0.29), center + Vector2(0, u * 0.22), ink, line_w)
			draw_line(center + Vector2(-u * 0.16, -u * 0.03), center + Vector2(u * 0.16, -u * 0.03), ink, line_w)
			var guard := PackedVector2Array([
				center + Vector2(0, -u * 0.20),
				center + Vector2(u * 0.12, -u * 0.05),
				center + Vector2(0, u * 0.10),
				center + Vector2(-u * 0.12, -u * 0.05),
			])
			draw_colored_polygon(guard, soft)
			draw_polyline(guard, ink, line_w)
		XiangqiLogic.ELEPHANT:
			# 象/相：耳朵、象头和向下的鼻梁
			draw_circle(center + Vector2(-u * 0.13, -u * 0.07), u * 0.17, soft)
			draw_circle(center + Vector2(-u * 0.13, -u * 0.07), u * 0.17, ink, false, line_w)
			draw_circle(center + Vector2(u * 0.08, -u * 0.05), u * 0.15, soft)
			draw_arc(center + Vector2(0, u * 0.01), u * 0.17, -0.2, 1.35, 16, ink, line_w)
			draw_line(center + Vector2(u * 0.14, u * 0.02), center + Vector2(u * 0.17, u * 0.22), ink, line_w)
			draw_line(center + Vector2(u * 0.17, u * 0.22), center + Vector2(u * 0.08, u * 0.27), ink, line_w)
		XiangqiLogic.HORSE:
			# 马：独立烈马头部、耳朵和鬃毛
			var horse := PackedVector2Array([
				center + Vector2(-u * 0.18, u * 0.24),
				center + Vector2(-u * 0.16, -u * 0.12),
				center + Vector2(-u * 0.06, -u * 0.31),
				center + Vector2(u * 0.01, -u * 0.18),
				center + Vector2(u * 0.18, -u * 0.27),
				center + Vector2(u * 0.11, -u * 0.04),
				center + Vector2(u * 0.22, u * 0.10),
				center + Vector2(u * 0.11, u * 0.23),
			])
			draw_colored_polygon(horse, soft)
			draw_polyline(horse, ink, line_w)
			draw_line(center + Vector2(-u * 0.10, -u * 0.20), center + Vector2(-u * 0.28, -u * 0.08), ink, line_w)
			draw_circle(center + Vector2(u * 0.08, -u * 0.06), u * 0.025, ink)
		XiangqiLogic.CHARIOT:
			# 車：战车车厢与双轮
			var body := Rect2(center + Vector2(-u * 0.23, -u * 0.12), Vector2(u * 0.46, u * 0.24))
			draw_rect(body, soft)
			draw_rect(body, ink, false, line_w)
			draw_circle(center + Vector2(-u * 0.17, u * 0.16), u * 0.10, soft)
			draw_circle(center + Vector2(-u * 0.17, u * 0.16), u * 0.10, ink, false, line_w)
			draw_circle(center + Vector2(u * 0.17, u * 0.16), u * 0.10, soft)
			draw_circle(center + Vector2(u * 0.17, u * 0.16), u * 0.10, ink, false, line_w)
			draw_line(center + Vector2(-u * 0.18, u * 0.04), center + Vector2(u * 0.18, u * 0.04), ink, line_w)
		XiangqiLogic.CANNON:
			# 炮/砲：炮架、炮管与炮口
			draw_line(center + Vector2(-u * 0.22, u * 0.16), center + Vector2(u * 0.22, u * 0.16), ink, line_w)
			draw_line(center + Vector2(-u * 0.15, u * 0.11), center + Vector2(-u * 0.15, u * 0.20), ink, line_w)
			draw_line(center + Vector2(u * 0.15, u * 0.11), center + Vector2(u * 0.15, u * 0.20), ink, line_w)
			draw_line(center + Vector2(-u * 0.18, 0), center + Vector2(u * 0.17, -u * 0.17), ink, line_w * 2.0)
			draw_circle(center + Vector2(u * 0.19, -u * 0.18), u * 0.065, soft)
			draw_arc(center + Vector2(u * 0.19, -u * 0.18), u * 0.065, 0, TAU, 16, ink, line_w)
		XiangqiLogic.PAWN:
			# 兵/卒：军帽、长矛与肩甲
			draw_arc(center + Vector2(0, -u * 0.08), u * 0.20, PI, TAU, 16, ink, line_w)
			draw_line(center + Vector2(0, -u * 0.30), center + Vector2(0, u * 0.20), ink, line_w)
			draw_line(center + Vector2(-u * 0.11, u * 0.08), center + Vector2(u * 0.11, u * 0.08), ink, line_w)
			draw_line(center + Vector2(-u * 0.19, u * 0.20), center + Vector2(u * 0.19, u * 0.20), ink, line_w)

func _draw_capture_effect(center: Vector2, t: float) -> void:
	# 吃子专属击杀：冲击波 + 交叉斩击 + 八向碎片。
	var s: float = _cell / 52.0
	var pulse: float = sin(t * PI)
	var ring_r: float = (10.0 + 31.0 * pulse) * s
	var danger := Color(ApplePalette.DANGER.r, ApplePalette.DANGER.g, ApplePalette.DANGER.b, 0.86 * (1.0 - t * 0.55))
	var gold := Color(ApplePalette.GOLD_BRIGHT.r, ApplePalette.GOLD_BRIGHT.g, ApplePalette.GOLD_BRIGHT.b, 0.9 * (1.0 - t))
	draw_circle(center, (7.0 + 10.0 * pulse) * s, Color(danger.r, danger.g, danger.b, 0.16))
	draw_arc(center, ring_r, 0, TAU, 40, danger, 3.0 * s)
	var slash_angle: float = -0.78 + t * 1.8
	for i in range(2):
		var angle: float = slash_angle + (PI * 0.5 if i == 1 else 0.0)
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center - dir * (10.0 * s), center + dir * (29.0 * s * pulse), gold, 3.0 * s)
	for i in range(8):
		var a: float = TAU * float(i) / 8.0 + 0.18
		var dir2 := Vector2(cos(a), sin(a))
		var start: Vector2 = center + dir2 * (16.0 + 4.0 * pulse) * s
		var finish: Vector2 = center + dir2 * (24.0 + 16.0 * pulse) * s
		draw_line(start, finish, Color(gold.r, gold.g, gold.b, 0.78 * (1.0 - t)), max(1.0, 1.8 * s))
	draw_circle(center, 3.5 * s, gold)

func _highlight_square(pos: Vector2i, col: Color, r: float) -> void:
	var c: Vector2 = board_to_local(pos.x, pos.y)
	var s: float = _cell / 52.0
	var rect := Rect2(c - Vector2(23, 23) * s, Vector2(46, 46) * s)
	_draw_rounded_rect(rect, r * s, col)

func _draw_square_ring(pos: Vector2i, col: Color, w: float, r: float) -> void:
	var c: Vector2 = board_to_local(pos.x, pos.y)
	var s: float = _cell / 52.0
	var rect := Rect2(c - Vector2(23, 23) * s, Vector2(46, 46) * s)
	_draw_rounded_rect_outline(rect, r * s, col, w * s)

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
