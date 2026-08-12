extends Node3D
class_name XiangqiBoard3D
const XiangqiPiece3DRef = preload("res://scenes/games/xiangqi/XiangqiPiece3D.gd")
## XiangqiBoard3D -- 真·3D手游棋盘
## 保留与 XiangqiGame.gd 完全兼容的信号/方法契约，内部用 Node3D + Camera3D + 射线拾取 + XiangqiPiece3D 实现

const XiangqiLogicRef = preload("res://scenes/games/xiangqi/XiangqiLogic.gd")

signal try_move(from: Vector2i, to: Vector2i)
signal square_selected(pos: Vector2i)

var board: Array = []
var selected: Vector2i = Vector2i(-1, -1)
var legal_targets: Array[Vector2i] = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)
var interactable: bool = true

# ── 3D 常量 ──
const CELL: float = 1.0
const BOARD_W: float = 8.0  # 8 * CELL
const BOARD_H: float = 9.0  # 9 * CELL
const BOARD_Y: float = 0.0
const PIECE_Y: float = 0.22

# ── 节点 ──
var _camera: Camera3D = null
var _light: DirectionalLight3D = null
var _env: WorldEnvironment = null
var _board_root: Node3D = null
var _board_surface: StaticBody3D = null
var _surface_shape: CollisionShape3D = null
var _grid_root: Node3D = null
var _pieces_root: Node3D = null
var _effects_root: Node3D = null
var _selection_markers: Node3D = null

# ── 棋子映射 pos -> XiangqiPiece3D ──
var _pieces: Dictionary = {} # Vector2i -> XiangqiPiece3D
var _piece_nodes: Array = []

# -- 动画状态 --
var _anim_tween: Tween = null
var _anim_y_tween: Tween = null
var _anim_scale_tween: Tween = null
var _is_anim: bool = false
var _anim_from: Vector2i = Vector2i(-1, -1)
var _anim_to: Vector2i = Vector2i(-1, -1)

# -- 输入状态 --
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_start_screen: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _pending_drag: bool = false
var _long_press_time: float = 0.0
var _long_press_threshold: float = 0.22
var _drag_threshold: float = 10.0
var _touch_down_pos: Vector2 = Vector2.ZERO
var _current_hover: Vector2i = Vector2i(-1, -1)
var _pulse_t: float = 0.0

# ── 高亮标记 ──
var _marker_selected: MeshInstance3D = null
var _marker_last_from: MeshInstance3D = null
var _marker_last_to: MeshInstance3D = null
var _marker_legals: Array[MeshInstance3D] = []
var _marker_captures: Array[MeshInstance3D] = []

const COL_SELECT: Color = Color("#E8C9A0")
const COL_LEGAL: Color = Color("#3AA99E")
const COL_CAPTURE: Color = Color("#D94A3D")
const COL_LAST: Color = Color("#FFF2B2", 0.42)

# ─────────────────────────────────────────────
func _ready() -> void:
	_build_3d_scene()
	set_process(true)
	set_process_unhandled_input(true)
	# Ensure %XiangqiBoard is resolvable (Node3D with unique_name)


func _process(delta: float) -> void:
	_pulse_t += delta * 2.4
	if _pulse_t > 1000:
		_pulse_t -= 1000
	if _pending_drag and not _is_dragging and _drag_from.x != -1:
		_long_press_time += delta
		if _long_press_time >= _long_press_threshold:
			_enter_drag()
	# 脉冲重绘标记
	if legal_targets.size() > 0 or _is_dragging:
		_update_marker_pulse()
	if _is_dragging:
		pass

# ── 3D 场景构建 ──
func _build_3d_scene() -> void:
	# Camera top-down ~52deg, fits portrait
	_camera = Camera3D.new()
	_camera.name = "BoardCamera"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 42.0
	_camera.near = 0.05
	_camera.far = 100.0
	_camera.position = Vector3(0, 14.0, 11.5)
	_camera.rotation_degrees = Vector3(-52, 0, 0)
	_camera.current = true
	add_child(_camera)

	# 顶光
	_light = DirectionalLight3D.new()
	_light.name = "Sun"
	_light.light_energy = 1.15
	_light.shadow_enabled = true
	_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_light.position = Vector3(4, 10, 4)
	_light.rotation_degrees = Vector3(-55, 35, 0)
	add_child(_light)

	# Environment
	_env = WorldEnvironment.new()
	_env.name = "Env"
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color("#0F1410")
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color("#FFF8EE", 0.22)
	env_res.ambient_light_energy = 0.85
	_env.environment = env_res
	add_child(_env)

	# Board root
	_board_root = Node3D.new()
	_board_root.name = "BoardRoot"
	add_child(_board_root)

	# Board slab (BoxMesh)
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(BOARD_W + 1.2, 0.28, BOARD_H + 1.2)
	var slab_mat := StandardMaterial3D.new()
	slab_mat.albedo_color = Color("#5C3410")
	slab_mat.roughness = 0.72
	slab_mat.metallic = 0.06
	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	slab.mesh = slab_mesh
	slab.material_override = slab_mat
	slab.position = Vector3(0, -0.14, 0)
	_board_root.add_child(slab)

	# Board paper (thin BoxMesh)
	var paper_mesh := BoxMesh.new()
	paper_mesh.size = Vector3(BOARD_W + 0.6, 0.04, BOARD_H + 0.6)
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color("#F5E6C8")
	paper_mat.roughness = 0.82
	paper_mat.metallic = 0.0
	var paper := MeshInstance3D.new()
	paper.name = "Paper"
	paper.mesh = paper_mesh
	paper.material_override = paper_mat
	paper.position = Vector3(0, 0.02, 0)
	_board_root.add_child(paper)

	# Board surface collider (ray picking only)
	_board_surface = StaticBody3D.new()
	_board_surface.name = "BoardSurface"
	_board_surface.collision_layer = 1
	_board_surface.collision_mask = 0
	_board_surface.position = Vector3(0, 0.04, 0)
	_board_root.add_child(_board_surface)
	_surface_shape = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(BOARD_W + 0.8, 0.5, BOARD_H + 0.8)
	_surface_shape.shape = box_shape
	_board_surface.add_child(_surface_shape)

	# 格线
	_grid_root = Node3D.new()
	_grid_root.name = "Grid"
	_board_root.add_child(_grid_root)
	_build_grid()

	# 棋子容器
	_pieces_root = Node3D.new()
	_pieces_root.name = "Pieces"
	add_child(_pieces_root)

	# 特效容器
	_effects_root = Node3D.new()
	_effects_root.name = "Effects"
	add_child(_effects_root)

	# 标记容器
	_selection_markers = Node3D.new()
	_selection_markers.name = "Markers"
	_board_root.add_child(_selection_markers)
	_build_markers()

func _build_grid() -> void:
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color("#3D2310", 0.78)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var line_mat_soft := StandardMaterial3D.new()
	line_mat_soft.albedo_color = Color("#3D2310", 0.32)
	line_mat_soft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var palace_mat := StandardMaterial3D.new()
	palace_mat.albedo_color = Color("#2B1E0F", 0.68)
	palace_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Horizontal lines (10)
	for y in range(10):
		var z: float = (y - 4.5) * CELL
		var m := BoxMesh.new()
		m.size = Vector3(BOARD_W, 0.01, 0.02)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = line_mat if y == 0 or y == 9 else line_mat_soft
		mi.position = Vector3(0, 0.05, z)
		_grid_root.add_child(mi)
	# 竖线
	for x in range(9):
		var cx: float = (x - 4) * CELL
		if x == 0 or x == 8:
			var m2 := BoxMesh.new()
			m2.size = Vector3(0.02, 0.01, BOARD_H)
			var mi2 := MeshInstance3D.new()
			mi2.mesh = m2
			mi2.material_override = line_mat
			mi2.position = Vector3(cx, 0.05, 0)
			_grid_root.add_child(mi2)
		else:
			# Two segments split by river
			var seg_h: float = 4.0 * CELL
			var m_top := BoxMesh.new()
			m_top.size = Vector3(0.02, 0.01, seg_h)
			var mi_top := MeshInstance3D.new()
			mi_top.mesh = m_top
			mi_top.material_override = line_mat_soft
			mi_top.position = Vector3(cx, 0.05, -2.5 * CELL)
			_grid_root.add_child(mi_top)
			var m_bot := BoxMesh.new()
			m_bot.size = Vector3(0.02, 0.01, seg_h)
			var mi_bot := MeshInstance3D.new()
			mi_bot.mesh = m_bot
			mi_bot.material_override = line_mat_soft
			mi_bot.position = Vector3(cx, 0.05, 2.5 * CELL)
			_grid_root.add_child(mi_bot)
	# 九宫斜线
	var palace_lines: Array = [
		[Vector2i(3, 0), Vector2i(5, 2)],
		[Vector2i(5, 0), Vector2i(3, 2)],
		[Vector2i(3, 7), Vector2i(5, 9)],
		[Vector2i(5, 7), Vector2i(3, 9)],
	]
	for seg in palace_lines:
		var a: Vector3 = logical_to_world(seg[0])
		var b: Vector3 = logical_to_world(seg[1])
		var mid: Vector3 = (a + b) * 0.5
		var dir: Vector3 = (b - a).normalized()
		var length: float = a.distance_to(b)
		var yaw: float = atan2(dir.x, dir.z)
		var m3 := BoxMesh.new()
		m3.size = Vector3(0.018, 0.01, length)
		var mi3 := MeshInstance3D.new()
		mi3.mesh = m3
		mi3.material_override = palace_mat
		mi3.position = Vector3(mid.x, 0.06, mid.z)
		mi3.rotation.y = yaw
		_grid_root.add_child(mi3)

	# River decoration (semi-transparent)
	var river_mesh := BoxMesh.new()
	river_mesh.size = Vector3(BOARD_W + 0.4, 0.008, 1.0 * CELL)
	var river_mat := StandardMaterial3D.new()
	river_mat.albedo_color = Color("#3AA99E", 0.08)
	river_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	river_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var river := MeshInstance3D.new()
	river.mesh = river_mesh
	river.material_override = river_mat
	river.position = Vector3(0, 0.055, 0)
	_grid_root.add_child(river)

	# River text (Label3D if available, otherwise skip)
	if ClassDB.class_exists("Label3D"):
		var lbl1: Node = ClassDB.instantiate("Label3D")
		lbl1.set("text", "Chu He")
		lbl1.set("font_size", 64)
		lbl1.set("modulate", Color("#2B1E0F", 0.42))
		lbl1.set("billboard", 0)
		if lbl1 is Node3D:
			(lbl1 as Node3D).position = Vector3(-2.0, 0.07, 0)
			(lbl1 as Node3D).rotation_degrees = Vector3(-90, 0, 0)
			(lbl1 as Node3D).scale = Vector3(0.018, 0.018, 0.018)
		_grid_root.add_child(lbl1)
		var lbl2: Node = ClassDB.instantiate("Label3D")
		lbl2.set("text", "Han Jie")
		lbl2.set("font_size", 64)
		lbl2.set("modulate", Color("#2B1E0F", 0.42))
		lbl2.set("billboard", 0)
		if lbl2 is Node3D:
			(lbl2 as Node3D).position = Vector3(2.0, 0.07, 0)
			(lbl2 as Node3D).rotation_degrees = Vector3(-90, 0, 0)
			(lbl2 as Node3D).scale = Vector3(0.018, 0.018, 0.018)
		_grid_root.add_child(lbl2)

func _build_markers() -> void:
	# Selection ring (gold Torus)
	_marker_selected = _make_ring(COL_SELECT, 0.46, 0.025, 0.06, false)
	_marker_selected.visible = false
	_selection_markers.add_child(_marker_selected)
	# Last move markers
	_marker_last_from = _make_ring(COL_LAST, 0.38, 0.018, 0.05, true)
	_marker_last_from.visible = false
	_selection_markers.add_child(_marker_last_from)
	_marker_last_to = _make_ring(COL_LAST, 0.44, 0.022, 0.05, true)
	_marker_last_to.visible = false
	_selection_markers.add_child(_marker_last_to)

func _make_ring(col: Color, inner: float, outer: float, y: float, transparent: bool) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 28
	mesh.ring_segments = 12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0, y, 0)
	mi.rotation_degrees = Vector3(90, 0, 0)
	return mi

func _ensure_legal_markers(count: int) -> void:
	while _marker_legals.size() < count:
		var mi := _make_ring(COL_LEGAL, 0.22, 0.020, 0.055, false)
		mi.visible = false
		_selection_markers.add_child(mi)
		_marker_legals.append(mi)
	while _marker_captures.size() < count:
		var mi2 := _make_ring(COL_CAPTURE, 0.36, 0.022, 0.055, false)
		mi2.visible = false
		_selection_markers.add_child(mi2)
		_marker_captures.append(mi2)

func _update_marker_pulse() -> void:
	var pulse: float = 1.0 + sin(_pulse_t * 3.0) * 0.06
	for mi in _marker_legals:
		if mi.visible:
			mi.scale = Vector3(pulse, pulse, 1.0)
	for mi in _marker_captures:
		if mi.visible:
			var p2: float = 1.0 + sin(_pulse_t * 4.0) * 0.08
			mi.scale = Vector3(p2, p2, 1.0)

# ── 坐标 ──
func logical_to_world(square: Vector2i) -> Vector3:
	# x 0..8 -> -4..4, y 0..9 -> -4.5..4.5, y=0 black side, y=9 red side
	return Vector3((square.x - 4) * CELL, BOARD_Y, (square.y - 4.5) * CELL)

func world_to_logical(world_pos: Vector3) -> Vector2i:
	var local: Vector3 = _board_root.to_local(world_pos) if _board_root != null else world_pos
	# local.y 接近 BOARD_Y，x/z 对应棋盘平面
	var bx: int = int(round(local.x / CELL + 4))
	var by: int = int(round(local.z / CELL + 4.5))
	return Vector2i(bx, by)

func board_to_local(bx: int, by: int) -> Vector2:
	# Compat helper
	return Vector2((bx - 4) * CELL, (by - 4.5) * CELL)

func local_to_board(p: Vector2) -> Vector2i:
	return Vector2i(int(round(p.x / CELL + 4)), int(round(p.y / CELL + 4.5)))

# ── 射线拾取 ──
func _screen_to_board(screen_pos: Vector2) -> Vector2i:
	if _camera == null or _board_surface == null:
		return Vector2i(-1, -1)
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	var end: Vector3 = origin + dir * 80.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return Vector2i(-1, -1)
	var hit_pos: Vector3 = hit["position"]
	var sq: Vector2i = world_to_logical(hit_pos)
	if not XiangqiLogicRef.inside_board(sq.x, sq.y):
		return Vector2i(-1, -1)
	# Snap: distance from hit point to nearest intersection
	var center: Vector3 = logical_to_world(sq)
	# Compare in board_root local xz
	var local_hit: Vector3 = _board_root.to_local(hit_pos) if _board_root != null else hit_pos
	var local_center: Vector3 = Vector3((sq.x - 4) * CELL, local_hit.y, (sq.y - 4.5) * CELL)
	var dist: float = Vector2(local_hit.x, local_hit.z).distance_to(Vector2(local_center.x, local_center.z))
	if dist > 0.58 * CELL:
		return Vector2i(-1, -1)
	return sq

# ─────────────────────────────────────────────
# 对外契约
# ─────────────────────────────────────────────
func set_board(b: Array) -> void:
	board = b
	_sync_pieces()

func set_selection(sel: Vector2i, targets: Array[Vector2i]) -> void:
	selected = sel
	legal_targets = targets
	_refresh_markers()

func set_last_move(f: Vector2i, t: Vector2i) -> void:
	last_move_from = f
	last_move_to = t
	_refresh_markers()

func is_animating() -> bool:
	return _is_anim

func cancel_animation() -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null
	if _anim_y_tween != null and _anim_y_tween.is_valid():
		_anim_y_tween.kill()
	_anim_y_tween = null
	if _anim_scale_tween != null and _anim_scale_tween.is_valid():
		_anim_scale_tween.kill()
	_anim_scale_tween = null
	_is_anim = false
	_anim_from = Vector2i(-1, -1)
	_anim_to = Vector2i(-1, -1)

func cancel_gesture() -> void:
	# Clear highlight of dragged piece if any (valid-drop paths previously left it on)
	if _drag_from.x != -1:
		var dp = _pieces.get(_drag_from, null)
		if dp != null and is_instance_valid(dp):
			dp.set_highlight(false)
	_is_dragging = false
	_pending_drag = false
	_drag_from = Vector2i(-1, -1)
	_long_press_time = 0.0
	_current_hover = Vector2i(-1, -1)

func _update_layout() -> void:
	# Compat: called from XiangqiGame._on_viewport_resized
	var vp: Vector2 = Vector2(720, 1280)
	if get_viewport() != null:
		vp = get_viewport().get_visible_rect().size
	update_layout(vp)

func update_layout(stage_size: Vector2) -> void:
	# 动态适配：根据视口宽高比调整相机距离/FOV，保证棋盘完整可见不溢出
	var size: Vector2 = stage_size
	if size.x <= 0 or size.y <= 0:
		size = Vector2(720, 1148)
	if _camera == null:
		return
	# 棋盘世界尺寸约 9.2 x 10.2 (含边距)
	var board_w: float = 9.2
	var board_h: float = 10.2
	var aspect: float = size.x / max(size.y, 1.0)
	# 竖屏 aspect < 1：需要更高相机视角；横屏 aspect > 1：更宽
	var target_fov: float = 42.0
	if aspect < 0.85:
		target_fov = 46.0
	elif aspect > 1.2:
		target_fov = 38.0
	_camera.fov = target_fov
		# 相机高度随 aspect 微调
	var cam_h: float = 14.0
	var cam_d: float = 11.5
	if aspect < 0.7:
		cam_h = 15.5
		cam_d = 12.5
	_camera.position = Vector3(0, cam_h, cam_d)
	_camera.rotation_degrees = Vector3(-52, 0, 0)

func get_board_pixel_size() -> Vector2:
	return Vector2(BOARD_W * 80, BOARD_H * 80)

# ── 棋子同步 ──
func _sync_pieces() -> void:
	if _pieces_root == null:
		return
	if board.is_empty():
		return
	# 收集目标位置
	var wanted: Dictionary = {} # Vector2i -> int piece
	for y in range(10):
		for x in range(9):
			var p: int = board[y][x]
			if p != 0:
				wanted[Vector2i(x, y)] = p
	# 删除多余
	var to_remove: Array = []
	for pos in _pieces.keys():
		if not wanted.has(pos):
			to_remove.append(pos)
		else:
			# 类型或阵营变化则重建
			var existing = _pieces[pos]
			if not is_instance_valid(existing):
				to_remove.append(pos)
				continue
			var want_piece: int = wanted[pos]
			var want_type: int = abs(want_piece)
			var want_side: int = XiangqiLogicRef.RED if want_piece > 0 else XiangqiLogicRef.BLACK
			# Compare via meta
			if existing.get_meta("piece_type", -1) != want_type or existing.get_meta("side", -1) != want_side:
				to_remove.append(pos)
	for pos in to_remove:
		var n: Node = _pieces[pos]
		if is_instance_valid(n):
			n.queue_free()
		_pieces.erase(pos)
	# 创建缺失
	for pos in wanted.keys():
		if _pieces.has(pos):
			# 仅更新位置（静止同步用瞬移）
			var ex = _pieces[pos]
			if is_instance_valid(ex):
				var w: Vector3 = logical_to_world(pos)
				ex.position = Vector3(w.x, PIECE_Y, w.z)
			continue
		var piece_val: int = wanted[pos]
		var ptype: int = abs(piece_val)
		var side: int = XiangqiLogicRef.RED if piece_val > 0 else XiangqiLogicRef.BLACK
		var piece := XiangqiPiece3DRef.new()
		_pieces_root.add_child(piece)
		piece.set_meta("piece_type", ptype)
		piece.set_meta("side", side)
		piece.setup(ptype, side)
		var wp: Vector3 = logical_to_world(pos)
		piece.position = Vector3(wp.x, PIECE_Y, wp.z)
		# Red faces north (-Z), black faces south (+Z)
		piece.rotation.y = 0 if side == XiangqiLogicRef.RED else PI
		_pieces[pos] = piece
	_refresh_markers()

func _refresh_markers() -> void:
	if _selection_markers == null:
		return
	# 选中
	if selected.x != -1 and _marker_selected != null:
		var w: Vector3 = logical_to_world(selected)
		_marker_selected.position = Vector3(w.x, 0.06, w.z)
		_marker_selected.visible = true
	else:
		if _marker_selected != null:
			_marker_selected.visible = false
	# Last move
	if last_move_from.x != -1 and _marker_last_from != null:
		var wf: Vector3 = logical_to_world(last_move_from)
		_marker_last_from.position = Vector3(wf.x, 0.05, wf.z)
		_marker_last_from.visible = not (_is_anim and _anim_from == last_move_from)
	else:
		if _marker_last_from != null:
			_marker_last_from.visible = false
	if last_move_to.x != -1 and _marker_last_to != null:
		var wt: Vector3 = logical_to_world(last_move_to)
		_marker_last_to.position = Vector3(wt.x, 0.05, wt.z)
		_marker_last_to.visible = not (_is_anim and _anim_to == last_move_to)
	else:
		if _marker_last_to != null:
			_marker_last_to.visible = false
	# Legal targets: capture vs empty
	_ensure_legal_markers(legal_targets.size())
	for i in range(_marker_legals.size()):
		_marker_legals[i].visible = false
	for i in range(_marker_captures.size()):
		_marker_captures[i].visible = false
	var li: int = 0
	var ci: int = 0
	for t in legal_targets:
		var is_cap: bool = false
		if not board.is_empty() and t.y >= 0 and t.y < 10 and t.x >= 0 and t.x < 9:
			is_cap = board[t.y][t.x] != 0
		var wp2: Vector3 = logical_to_world(t)
		if is_cap:
			if ci < _marker_captures.size():
				_marker_captures[ci].position = Vector3(wp2.x, 0.055, wp2.z)
				_marker_captures[ci].visible = true
				ci += 1
		else:
			if li < _marker_legals.size():
				_marker_legals[li].position = Vector3(wp2.x, 0.055, wp2.z)
				_marker_legals[li].visible = true
				li += 1

# ── 动画 ──
func animate_move(from: Vector2i, to: Vector2i, piece: int = 0, captured: int = 0) -> void:
	if from.x < 0 or to.x < 0:
		return
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null
	if _anim_y_tween != null and _anim_y_tween.is_valid():
		_anim_y_tween.kill()
	_anim_y_tween = null
	if _anim_scale_tween != null and _anim_scale_tween.is_valid():
		_anim_scale_tween.kill()
	_anim_scale_tween = null
	var p: int = piece
	if p == 0 and from.y >= 0 and from.y < 10 and from.x >= 0 and from.x < 9 and not board.is_empty():
		p = board[from.y][from.x]
	if p == 0:
		return
	_anim_from = from
	_anim_to = to
	_is_anim = true
	cancel_gesture()
	_refresh_markers()

	var mover = _pieces.get(from, null)
	if mover == null or not is_instance_valid(mover):
		_is_anim = false
		_refresh_markers()
		return

	var world_from: Vector3 = logical_to_world(from)
	var world_to: Vector3 = logical_to_world(to)
	var dist: float = Vector2(from).distance_to(Vector2(to))
	var dur: float = clamp(0.24 + dist * 0.022, 0.26, 0.50)
	if dist >= 5:
		dur += 0.04
	var is_capture: bool = captured != 0

	var victim = _pieces.get(to, null) if is_capture else null

	if victim != null and is_instance_valid(victim):
		victim.play_death(dur * 0.72)

	# Capture flash near impact.
	var lift_h: float
	if p != 0 and mover != null and mover.has_method("_move_jump_height"):
		var base_h: float = mover.call("_move_jump_height")
		lift_h = clamp(base_h + dist * 0.08, 0.35, 1.6)
	else:
		lift_h = clamp(world_from.distance_to(world_to) * 0.18, 0.55, 1.6)
	var to_v: Vector3 = Vector3(world_to.x, PIECE_Y, world_to.z)
	var mid_y: float = PIECE_Y + lift_h
	if is_capture and mover.has_method("_do_impact_flash"):
		var _flash_mover = mover
		get_tree().create_timer(dur * 0.42).timeout.connect(func() -> void:
			if is_instance_valid(_flash_mover):
				_flash_mover._do_impact_flash(0.12)
		, CONNECT_ONE_SHOT)
	# XZ linear over full dur.
	_anim_tween = create_tween()
	_anim_tween.tween_property(mover, "position:x", to_v.x, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.parallel().tween_property(mover, "position:z", to_v.z, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Y two-phase on its own tween so chain does not push past dur.
	_anim_y_tween = create_tween()
	_anim_y_tween.tween_property(mover, "position:y", mid_y, dur * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_y_tween.tween_property(mover, "position:y", PIECE_Y, dur * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	# Pulse scale chained within dur as well.
	_anim_scale_tween = create_tween()
	_anim_scale_tween.tween_property(mover, "scale", Vector3(1.06, 1.06, 1.06), dur * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_scale_tween.tween_property(mover, "scale", Vector3.ONE, dur * 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	if is_capture:
		_shake_camera(0.09, 0.06)

	var fin_dur: float = dur
	await get_tree().create_timer(fin_dur).timeout
	if not is_inside_tree() or not _is_anim:
		return
	if victim != null and is_instance_valid(victim):
		victim.queue_free()
	if _pieces.has(from):
		_pieces.erase(from)
	_pieces[to] = mover
	mover.position = Vector3(world_to.x, PIECE_Y, world_to.z)
	mover.scale = Vector3.ONE
	if mover.has_method("play_idle"):
		mover.play_idle()
	_is_anim = false
	_anim_from = Vector2i(-1, -1)
	_anim_to = Vector2i(-1, -1)
	_anim_tween = null
	_anim_y_tween = null
	_anim_scale_tween = null
	_refresh_markers()
	_try_haptic(16)

func _shake_camera(duration: float, strength: float) -> void:
	if _camera == null:
		return
	var orig: Vector3 = _camera.position
	var tw := create_tween()
	tw.tween_property(_camera, "position", orig + Vector3(strength, 0, -strength * 0.5), duration * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_camera, "position", orig, duration * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# ── 输入 ──
func _unhandled_input(event: InputEvent) -> void:
	if not interactable or _is_anim:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	# 触屏
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_touch_down_pos = st.position
			_drag_start_screen = st.position
			var sq: Vector2i = _screen_to_board(st.position)
			if sq.x == -1:
				_pending_drag = false
				_drag_from = Vector2i(-1, -1)
				_long_press_time = 0.0
				return
			var pv: int = 0
			if not board.is_empty() and sq.y >= 0 and sq.y < 10 and sq.x >= 0 and sq.x < 9:
				pv = board[sq.y][sq.x]
			if selected.x != -1 and sq == selected and pv != 0:
				_drag_from = sq
				_pending_drag = true
				_long_press_time = 0.0
			elif pv != 0:
				square_selected.emit(sq)
				_try_haptic(10)
				_drag_from = sq
				_pending_drag = true
				_long_press_time = 0.0
			else:
				if selected.x != -1:
					for t in legal_targets:
						if t == sq:
							try_move.emit(selected, sq)
							_drag_from = Vector2i(-1, -1)
							_pending_drag = false
							get_viewport().set_input_as_handled()
							return
					square_selected.emit(Vector2i(-1, -1))
			get_viewport().set_input_as_handled()
		else:
			var rel: Vector2 = st.position
			if _is_dragging and _drag_from.x != -1:
				var drop: Vector2i = _screen_to_board(rel)
				var valid: bool = false
				if drop.x != -1:
					for t in legal_targets:
						if t == drop:
							valid = true
							break
				if valid:
					var fc: Vector2i = _drag_from
					var dp2 = _pieces.get(_drag_from, null)
					if dp2 != null and is_instance_valid(dp2):
						dp2.set_highlight(false)
					_is_dragging = false
					_pending_drag = false
					_drag_from = Vector2i(-1, -1)
					_long_press_time = 0.0
					try_move.emit(fc, drop)
				else:
					_do_bounce_back()
				get_viewport().set_input_as_handled()
				return
			if _pending_drag:
				_pending_drag = false
				_long_press_time = 0.0
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _drag_from.x == -1:
			return
		var moved: float = sd.position.distance_to(_drag_start_screen)
		if _pending_drag and not _is_dragging:
			if moved > _drag_threshold:
				_enter_drag()
		if _is_dragging:
			_update_drag_hover(sd.position)
			get_viewport().set_input_as_handled()
		return
	# 鼠标
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_touch_down_pos = event.position
		_drag_start_screen = event.position
		var sq2: Vector2i = _screen_to_board(event.position)
		if sq2.x == -1:
			_pending_drag = false
			_drag_from = Vector2i(-1, -1)
			_long_press_time = 0.0
			return
		if selected.x != -1:
			for t in legal_targets:
				if t == sq2:
					try_move.emit(selected, sq2)
					return
		var p2: int = 0
		if not board.is_empty() and sq2.y >= 0 and sq2.y < 10 and sq2.x >= 0 and sq2.x < 9:
			p2 = board[sq2.y][sq2.x]
		if p2 != 0:
			square_selected.emit(sq2)
			_drag_from = sq2
			_pending_drag = true
			_long_press_time = 0.0
			_is_dragging = false
			_try_haptic(10)
		else:
			square_selected.emit(Vector2i(-1, -1))
			_drag_from = Vector2i(-1, -1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_dragging and _drag_from.x != -1:
			var drop2: Vector2i = _screen_to_board(event.position)
			var ok: bool = false
			if drop2.x != -1:
				for t in legal_targets:
					if t == drop2:
						ok = true
						break
			if ok:
				var fc2: Vector2i = _drag_from
				var dp3 = _pieces.get(_drag_from, null)
				if dp3 != null and is_instance_valid(dp3):
					dp3.set_highlight(false)
				_is_dragging = false
				_pending_drag = false
				_drag_from = Vector2i(-1, -1)
				try_move.emit(fc2, drop2)
			else:
				_do_bounce_back()
			get_viewport().set_input_as_handled()
			return
		if _pending_drag:
			_pending_drag = false
			_long_press_time = 0.0
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _drag_from.x == -1:
			return
		if not _is_dragging and _pending_drag:
			if event.position.distance_to(_drag_start_screen) > _drag_threshold:
				_enter_drag()
		if _is_dragging:
			_update_drag_hover(event.position)
			get_viewport().set_input_as_handled()

func _enter_drag() -> void:
	if _drag_from.x == -1 or _is_dragging:
		return
	_is_dragging = true
	_pending_drag = false
	var piece = _pieces.get(_drag_from, null)
	if piece != null and is_instance_valid(piece):
		piece.set_highlight(true)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_pickup"):
		am.call("play_pickup")
	_try_haptic(14)

func _update_drag_hover(screen_pos: Vector2) -> void:
	var sq: Vector2i = _screen_to_board(screen_pos)
	_current_hover = sq
	# 悬浮棋子跟随（抬高）
	var piece = _pieces.get(_drag_from, null)
	if piece != null and is_instance_valid(piece) and sq.x != -1:
		var w: Vector3 = logical_to_world(sq)
		piece.position = Vector3(w.x, PIECE_Y + 0.55, w.z)

func _do_bounce_back() -> void:
	if _drag_from.x == -1:
		_is_dragging = false
		_pending_drag = false
		return
	var piece = _pieces.get(_drag_from, null)
	var home: Vector3 = logical_to_world(_drag_from)
	home.y = PIECE_Y
	_is_dragging = false
	_pending_drag = false
	if piece != null and is_instance_valid(piece):
		piece.set_highlight(false)
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(piece, "position", home, 0.28)
		tw.tween_callback(func() -> void:
			_drag_from = Vector2i(-1, -1)
			_long_press_time = 0.0
		)
	else:
		_drag_from = Vector2i(-1, -1)
		_long_press_time = 0.0
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_bounce_back"):
			am.call("play_bounce_back")
		elif am.has_method("play_invalid"):
			am.call("play_invalid")
	_try_haptic(36)

func _try_haptic(ms: int) -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() in ["Android", "iOS"]:
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(ms)
