extends Node3D
class_name XiangqiPiece3D
## XiangqiPiece3D —— 象棋 7 类棋子的 3D 表现基类（将/帅+车 高表现占位）
## 使用 Godot 原生 PrimitiveMesh 组合拼装，不依赖外部模型，gl_compatibility 兼容
## 每类棋子均由 底座(Base)/主体(Body)/顶部装饰(Top) 三层结构组成，一眼可区分
## 红方暖红+金饰，黑方玄黑+银饰，材质均用 StandardMaterial3D 赋质感
## 对应 XiangqiLogic 常量：1=将帅(KING) 2=士仕(ADVISOR) 3=象相(ELEPHANT) 4=马(HORSE) 5=车(CHARIOT) 6=炮(CANNON) 7=兵卒(PAWN)

# ─────────────────────────────────────────────────────────────
# 常量（与 XiangqiLogic 保持一致，本地冗余以免硬依赖加载顺序）
# ─────────────────────────────────────────────────────────────
const KING := 1       # 将/帅
const ADVISOR := 2    # 士/仕
const ELEPHANT := 3   # 象/相
const HORSE := 4      # 马
const CHARIOT := 5    # 车
const CANNON := 6     # 炮
const PAWN := 7       # 兵/卒

const SIDE_RED := 1   # XiangqiLogic.RED
const SIDE_BLACK := 2 # XiangqiLogic.BLACK

# ─────────────────────────────────────────────────────────────
# 颜色板（取自 ApplePalette.gd，天天象棋暖木质感）
# 红方：暖朱红 + 鎏金，黑方：玄黑 + 银霜，gl下亦有金属质感
# ─────────────────────────────────────────────────────────────
const COL_RED_PRIMARY: Color = Color("#C1272D")
const COL_RED_DEEP: Color = Color("#8E1B1E")
const COL_RED_BODY: Color = Color("#B82227")
const COL_RED_GOLD: Color = Color("#C8A46A")
const COL_RED_GOLD_BRIGHT: Color = Color("#E8C9A0")
const COL_RED_JEWEL: Color = Color("#FF3B30")

const COL_BLACK_PRIMARY: Color = Color("#1A1A1E")
const COL_BLACK_DEEP: Color = Color("#111114")
const COL_BLACK_BODY: Color = Color("#232326")
const COL_BLACK_RING: Color = Color("#2F2F33")
const COL_SILVER: Color = Color("#D0D6DE")
const COL_SILVER_DEEP: Color = Color("#9AA3B2")
const COL_STEEL: Color = Color("#8A9099")

const COL_IVORY: Color = Color("#FFF8EE")
const COL_WOOD: Color = Color("#8B5A2B")
const COL_BRONZE: Color = Color("#8C6A3A")
const COL_MANE: Color = Color("#5A2E12")
const COL_JADE: Color = Color("#3AA99E")

# ─────────────────────────────────────────────────────────────
# 节点结构
# XiangqiPiece3D (Node3D) —— 逻辑位移节点，外部直接改 position
#   └─ RootVisual (Node3D) —— 视觉总根，所有姿态动画作用于此，避免与位移冲突
#       ├─ Base (Node3D) —— 底座层
#       ├─ Body (Node3D) —— 主体层
#       └─ Top  (Node3D) —— 顶部装饰层
#   ├─ SelectRing (MeshInstance3D) —— 选中环，固定于棋子脚下
#   └─ HighlightRing (MeshInstance3D) —— 可走/高亮环
# ─────────────────────────────────────────────────────────────
var _piece_type: int = 0
var _side: int = 0
var _is_red: bool = true

var _root_visual: Node3D = null
var _base_node: Node3D = null
var _body_node: Node3D = null
var _top_node: Node3D = null

var _select_ring: MeshInstance3D = null
var _highlight_ring: MeshInstance3D = null

var _pick_body: StaticBody3D = null
var _pick_shape: CollisionShape3D = null

# 材质（每棋子一套实例，不共享，以免死亡淡出互相影响）
var _mat_base: StandardMaterial3D = null
var _mat_body: StandardMaterial3D = null
var _mat_trim: StandardMaterial3D = null  # 金/银饰
var _mat_accent: StandardMaterial3D = null # 象牙/棕鬃等通用辅色(按需覆盖)

# 动画句柄
var _idle_tween: Tween = null
var _move_tween: Tween = null
var _pose_tween: Tween = null
var _select_tween: Tween = null
var _select_pulse_tween: Tween = null
var _highlight_tween: Tween = null
var _death_tweens: Array[Tween] = []

var _is_selected: bool = false
var _is_highlighted: bool = false


# ─────────────────────────────────────────────────────────────
# 工具：材质 / Mesh
# ─────────────────────────────────────────────────────────────

## 创建标准材质，gl_compatibility 下 metallic/roughness 仍有效
func _make_mat(albedo: Color, metallic: float, roughness: float, emission_col: Color = Color(0, 0, 0, 0), emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = roughness
	# gl_compatibility 下不需要次表面等高级特性，保持基础质感即可
	if emission_energy > 0.0 or emission_col.a > 0.0:
		m.emission_enabled = true
		m.emission = emission_col
		m.emission_energy_multiplier = emission_energy
	# 默认不透明，死亡时再切为 ALPHA，避免批量透明排序开销
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m

## 向 parent 添加一个 PrimitiveMesh 的 MeshInstance3D
func _add_mesh(parent: Node3D, mesh: PrimitiveMesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

## 确保三层 Node3D 结构存在（兼容场景预制：优先复用已存在的同名子节点）
func _ensure_structure() -> void:
	# 兼容 tscn 预制：若场景中已存在同名节点则复用，避免重复创建
	if _root_visual == null or not is_instance_valid(_root_visual):
		_root_visual = get_node_or_null("RootVisual") as Node3D
	if _base_node == null or not is_instance_valid(_base_node):
		_base_node = get_node_or_null("RootVisual/Base") as Node3D
	if _body_node == null or not is_instance_valid(_body_node):
		_body_node = get_node_or_null("RootVisual/Body") as Node3D
	if _top_node == null or not is_instance_valid(_top_node):
		_top_node = get_node_or_null("RootVisual/Top") as Node3D
	if _pick_body == null or not is_instance_valid(_pick_body):
		_pick_body = get_node_or_null("PickBody") as StaticBody3D
		if _pick_body != null:
			_pick_shape = _pick_body.get_node_or_null("PickShape") as CollisionShape3D
	if _root_visual != null and is_instance_valid(_root_visual) and _base_node != null and is_instance_valid(_base_node) and _body_node != null and is_instance_valid(_body_node) and _top_node != null and is_instance_valid(_top_node):
		_ensure_pick_collision()
		return
	if _root_visual == null or not is_instance_valid(_root_visual):
		_root_visual = Node3D.new()
		_root_visual.name = "RootVisual"
		add_child(_root_visual)
	if _base_node == null or not is_instance_valid(_base_node):
		_base_node = Node3D.new()
		_base_node.name = "Base"
		_root_visual.add_child(_base_node)
	if _body_node == null or not is_instance_valid(_body_node):
		_body_node = Node3D.new()
		_body_node.name = "Body"
		_root_visual.add_child(_body_node)
	if _top_node == null or not is_instance_valid(_top_node):
		_top_node = Node3D.new()
		_top_node.name = "Top"
		_root_visual.add_child(_top_node)

	_ensure_pick_collision()

## 确保拾取碰撞体存在（用于射线拾取 - StaticBody + CollisionShape3D）
func _ensure_pick_collision() -> void:
	if _pick_body != null and is_instance_valid(_pick_body):
		return
	_pick_body = StaticBody3D.new()
	_pick_body.name = "PickBody"
	_pick_body.collision_layer = 2
	_pick_body.collision_mask = 0
	add_child(_pick_body)
	_pick_shape = CollisionShape3D.new()
	_pick_shape.name = "PickShape"
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 1.8
	_pick_shape.shape = shape
	_pick_shape.position = Vector3(0, 0.9, 0)
	_pick_body.add_child(_pick_shape)

## 更新拾取形状以匹配棋子类型（差异化高度/半径）
func _update_pick_shape() -> void:
	if _pick_shape == null or not is_instance_valid(_pick_shape):
		return
	var shape := _pick_shape.shape as CylinderShape3D
	if shape == null:
		shape = CylinderShape3D.new()
		_pick_shape.shape = shape
	match _piece_type:
		KING:
			shape.radius = 0.52
			shape.height = 1.85
			_pick_shape.position = Vector3(0, 0.92, 0)
		CHARIOT:
			shape.radius = 0.58
			shape.height = 1.10
			_pick_shape.position = Vector3(0, 0.55, 0)
		HORSE:
			shape.radius = 0.54
			shape.height = 1.45
			_pick_shape.position = Vector3(0, 0.72, 0)
		CANNON:
			shape.radius = 0.53
			shape.height = 1.00
			_pick_shape.position = Vector3(0, 0.50, 0)
		ELEPHANT:
			shape.radius = 0.58
			shape.height = 1.35
			_pick_shape.position = Vector3(0, 0.68, 0)
		ADVISOR:
			shape.radius = 0.48
			shape.height = 1.55
			_pick_shape.position = Vector3(0, 0.78, 0)
		PAWN:
			shape.radius = 0.45
			shape.height = 1.05
			_pick_shape.position = Vector3(0, 0.52, 0)
		_:
			shape.radius = 0.50
			shape.height = 1.20
			_pick_shape.position = Vector3(0, 0.60, 0)

## 清理旧棋子模型与动画，重置姿态
func _clear_piece() -> void:
	# 停掉所有动画
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = null
	if _select_tween != null and _select_tween.is_valid():
		_select_tween.kill()
	_select_tween = null
	if _select_pulse_tween != null and _select_pulse_tween.is_valid():
		_select_pulse_tween.kill()
	_select_pulse_tween = null
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = null
	_kill_death_tweens()

	# 清理三层下的 Mesh
	if _root_visual != null and is_instance_valid(_root_visual):
		for layer in [_base_node, _body_node, _top_node]:
			if layer == null or not is_instance_valid(layer):
				continue
			for c in layer.get_children():
				c.queue_free()
		_root_visual.position = Vector3.ZERO
		_root_visual.rotation = Vector3.ZERO
		_root_visual.scale = Vector3.ONE
		if _base_node:
			_base_node.position = Vector3.ZERO; _base_node.rotation = Vector3.ZERO; _base_node.scale = Vector3.ONE
		if _body_node:
			_body_node.position = Vector3.ZERO; _body_node.rotation = Vector3.ZERO; _body_node.scale = Vector3.ONE
		if _top_node:
			_top_node.position = Vector3.ZERO; _top_node.rotation = Vector3.ZERO; _top_node.scale = Vector3.ONE

	if _select_ring != null and is_instance_valid(_select_ring):
		_select_ring.queue_free()
		_select_ring = null
	if _highlight_ring != null and is_instance_valid(_highlight_ring):
		_highlight_ring.queue_free()
		_highlight_ring = null

	visible = true
	scale = Vector3.ONE
	rotation = Vector3.ZERO
	_is_selected = false
	_is_highlighted = false

## 按红黑创建三套主材质
func _create_materials(is_red: bool) -> void:
	if is_red:
		# 红方：暖红主体 + 鎏金饰
		_mat_base = _make_mat(COL_RED_PRIMARY, 0.22, 0.48)
		_mat_body = _make_mat(COL_RED_BODY, 0.30, 0.42)
		_mat_trim = _make_mat(COL_RED_GOLD, 0.74, 0.30, COL_RED_GOLD, 0.22)
		# 辅色：暖白象牙用于点缀
		_mat_accent = _make_mat(COL_IVORY, 0.05, 0.38)
	else:
		# 黑方：玄黑主体 + 银霜饰
		_mat_base = _make_mat(COL_BLACK_PRIMARY, 0.32, 0.40)
		_mat_body = _make_mat(COL_BLACK_BODY, 0.36, 0.38)
		_mat_trim = _make_mat(COL_SILVER, 0.78, 0.24, COL_SILVER, 0.18)
		_mat_accent = _make_mat(Color("#E8EBEF"), 0.08, 0.35)

## 创建选中/高亮光环，固定于脚下，随选中可见
func _create_rings(is_red: bool) -> void:
	# 选中环：鎏金/银白发光 Torus
	var sel_mesh := TorusMesh.new()
	sel_mesh.inner_radius = 0.46
	sel_mesh.outer_radius = 0.020
	sel_mesh.rings = 24
	sel_mesh.ring_segments = 12
	var sel_col: Color = COL_RED_GOLD_BRIGHT if is_red else COL_SILVER
	var sel_mat := _make_mat(sel_col, 0.55, 0.32, sel_col, 1.05)
	sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sel_mat.albedo_color.a = 0.96
	sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_select_ring = MeshInstance3D.new()
	_select_ring.name = "SelectRing"
	_select_ring.mesh = sel_mesh
	_select_ring.material_override = sel_mat
	_select_ring.position = Vector3(0, 0.025, 0)
	_select_ring.rotation = Vector3(deg_to_rad(90), 0, 0)
	_select_ring.visible = false
	_select_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_select_ring)

	# 高亮环：青玉/金色薄环，用于可落点提示
	var hl_mesh := TorusMesh.new()
	hl_mesh.inner_radius = 0.52
	hl_mesh.outer_radius = 0.016
	hl_mesh.rings = 24
	hl_mesh.ring_segments = 10
	var hl_col: Color = Color("#3AA99E") if is_red else Color("#C8A46A")
	hl_col.a = 0.72
	var hl_mat := _make_mat(hl_col, 0.45, 0.40, hl_col, 0.85)
	hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hl_mat.albedo_color = hl_col
	hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_ring = MeshInstance3D.new()
	_highlight_ring.name = "HighlightRing"
	_highlight_ring.mesh = hl_mesh
	_highlight_ring.material_override = hl_mat
	_highlight_ring.position = Vector3(0, 0.022, 0)
	_highlight_ring.rotation = Vector3(deg_to_rad(90), 0, 0)
	_highlight_ring.visible = false
	_highlight_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight_ring)

## 收集所有 MeshInstance 的独立材质（去重），用于死亡淡出
func _collect_materials() -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	var seen := {}
	var stack: Array[Node] = []
	if _root_visual != null and is_instance_valid(_root_visual):
		stack.append(_root_visual)
	if _select_ring != null and is_instance_valid(_select_ring):
		stack.append(_select_ring)
	if _highlight_ring != null and is_instance_valid(_highlight_ring):
		stack.append(_highlight_ring)
	# 额外：自身下的其他装饰Mesh
	for c in get_children():
		if c is MeshInstance3D and c != _select_ring and c != _highlight_ring:
			stack.append(c)
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var m0 := mi.material_override as StandardMaterial3D
			if m0 != null:
				var id0 := m0.get_instance_id()
				if not seen.has(id0):
					seen[id0] = true
					out.append(m0)
			for j in mi.get_surface_override_material_count():
				var sm := mi.get_surface_override_material(j) as StandardMaterial3D
				if sm != null:
					var id1 := sm.get_instance_id()
					if not seen.has(id1):
						seen[id1] = true
						out.append(sm)
		for child in n.get_children():
			stack.append(child)
	return out

## 将收集到的材质切为可透明，为淡出做准备
func _prepare_fade() -> void:
	var mats := _collect_materials()
	for m in mats:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _stop_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null

func _kill_move_tween() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = null

func _kill_death_tweens() -> void:
	for tw in _death_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_death_tweens.clear()

func _track_death_tween(tw: Tween) -> Tween:
	if tw != null:
		_death_tweens.append(tw)
	return tw


# ─────────────────────────────────────────────────────────────
# 对外：setup / 状态
# ─────────────────────────────────────────────────────────────

## 初始化棋子类型与阵营，内部会清空旧模型并按类型拼装
## spec: setup(type, side, pos) — type=1..7, side=RED/BLACK, pos=Vector2i/Vector3/Vector2 兼容
func setup(piece_type: int, side: int, pos = null) -> void:
	_piece_type = clampi(piece_type, 1, 7)
	_side = side
	# side 取值与 XiangqiLogic 一致：RED=1, BLACK=2
	_is_red = (side == SIDE_RED)

	_clear_piece()
	_ensure_structure()
	_create_materials(_is_red)

	match _piece_type:
		KING:
			_build_king(_is_red)
		ADVISOR:
			_build_advisor(_is_red)
		ELEPHANT:
			_build_elephant(_is_red)
		HORSE:
			_build_horse(_is_red)
		CHARIOT:
			_build_chariot(_is_red)
		CANNON:
			_build_cannon(_is_red)
		PAWN:
			_build_pawn(_is_red)
		_:
			_build_pawn(_is_red)

	_create_rings(_is_red)
	_update_pick_shape()
	# 若传入位置则直接应用（兼容 Vector2i 棋盘坐标 与 Vector3 世界坐标）
	if pos != null:
		if pos is Vector2i:
			if pos.x >= 0 and pos.y >= 0:
				# 复用 Board 的 BOARD 转换逻辑：CELL=1.0, PIECE_Y=0.22
				position = Vector3((pos.x - 4) * 1.0, 0.22, (pos.y - 4.5) * 1.0)
		elif pos is Vector2:
			position = Vector3(pos.x, 0.22, pos.y)
		elif pos is Vector3:
			position = pos
	# 入场后自动待机微动
	if is_inside_tree():
		play_idle()
	else:
		# 尚未入树时延迟一帧再播
		call_deferred("play_idle")

# ─────────────────────────────────────────────────────────────
# 七类棋子拼装 —— 每类均有 底座/主体/顶部 三层，多 MeshInstance 组合
# 使用 BoxMesh / CylinderMesh / SphereMesh / CapsuleMesh / TorusMesh / PrismMesh
# ─────────────────────────────────────────────────────────────

# ——— 1. 将帅 KING — 帝王形象，皇冠/龙袍元素，厚重威严 ———
# 行走：庄重滑步+披风飘动；击杀：将帅御驾亲征，剑气斩击；死亡：王座崩塌+皇冠滚落
func _build_king(is_red: bool) -> void:
	# 材质细分
	var mat_base := _mat_base
	var mat_body := _mat_body
	var mat_gold := _mat_trim
	# 宝石/珠顶 独立材质
	var jewel_col: Color = COL_RED_JEWEL if is_red else Color("#5AC8FA")
	var mat_jewel := _make_mat(jewel_col, 0.15, 0.26, jewel_col, 0.65)
	var mat_dark_gold := _make_mat(COL_BRONZE, 0.62, 0.34, COL_BRONZE, 0.18)

	# ── 底座层：双层龙纹台 + 环饰 ──
	var base_low := CylinderMesh.new()
	base_low.top_radius = 0.50; base_low.bottom_radius = 0.54; base_low.height = 0.14; base_low.radial_segments = 24
	_add_mesh(_base_node, base_low, mat_base, Vector3(0, 0.07, 0))

	var base_ring := TorusMesh.new()
	base_ring.inner_radius = 0.46; base_ring.outer_radius = 0.028; base_ring.rings = 24; base_ring.ring_segments = 12
	_add_mesh(_base_node, base_ring, mat_gold, Vector3(0, 0.135, 0), Vector3(deg_to_rad(90), 0, 0))

	var base_mid := CylinderMesh.new()
	base_mid.top_radius = 0.42; base_mid.bottom_radius = 0.46; base_mid.height = 0.11; base_mid.radial_segments = 20
	_add_mesh(_base_node, base_mid, mat_dark_gold, Vector3(0, 0.195, 0))

	var base_upper := CylinderMesh.new()
	base_upper.top_radius = 0.38; base_upper.bottom_radius = 0.42; base_upper.height = 0.10; base_upper.radial_segments = 20
	_add_mesh(_base_node, base_upper, mat_base, Vector3(0, 0.300, 0))

	# 龙鳞立柱 四根 (Box) 环绕底台
	for i in 4:
		var ang: float = i * PI * 0.5
		var bx := BoxMesh.new(); bx.size = Vector3(0.06, 0.16, 0.06)
		_add_mesh(_base_node, bx, mat_gold, Vector3(cos(ang) * 0.40, 0.30, sin(ang) * 0.40), Vector3(0, -ang, 0))

	# ── 主体层：高达威严，龙纹竖柱 + 腰带 + 披风下摆 ──
	var body_pillar := CylinderMesh.new()
	body_pillar.top_radius = 0.30; body_pillar.bottom_radius = 0.34; body_pillar.height = 0.78; body_pillar.radial_segments = 18
	_add_mesh(_body_node, body_pillar, mat_body, Vector3(0, 0.74, 0))

	# 正面龙纹 Prism 竖条
	var dragon_prism := PrismMesh.new(); dragon_prism.size = Vector3(0.14, 0.68, 0.06)
	_add_mesh(_body_node, dragon_prism, mat_gold, Vector3(0, 0.76, 0.28), Vector3(deg_to_rad(90), 0, 0))

	# 背后披风（薄 Box 曲面拟）
	var cape := BoxMesh.new(); cape.size = Vector3(0.52, 0.62, 0.05)
	_add_mesh(_body_node, cape, mat_dark_gold, Vector3(0, 0.74, -0.30), Vector3(deg_to_rad(4), 0, 0))

	# 腰带 Torus
	var belt := TorusMesh.new(); belt.inner_radius = 0.31; belt.outer_radius = 0.032; belt.rings = 18; belt.ring_segments = 10
	_add_mesh(_body_node, belt, mat_gold, Vector3(0, 0.56, 0), Vector3(deg_to_rad(90), 0, 0))
	# 腰带玉佩 Box
	var yupei := BoxMesh.new(); yupei.size = Vector3(0.10, 0.14, 0.03)
	_add_mesh(_body_node, yupei, mat_jewel, Vector3(0, 0.50, 0.31), Vector3.ZERO)

	# 肩甲 左右 Box
	var shoulder_l := BoxMesh.new(); shoulder_l.size = Vector3(0.16, 0.10, 0.14)
	_add_mesh(_body_node, shoulder_l, mat_gold, Vector3(-0.30, 0.98, 0), Vector3(0, 0, deg_to_rad(-8)))
	var shoulder_r: BoxMesh = BoxMesh.new(); shoulder_r.size = Vector3(0.16, 0.10, 0.14)
	_add_mesh(_body_node, shoulder_r, mat_gold, Vector3(0.30, 0.98, 0), Vector3(0, 0, deg_to_rad(8)))

	# ── 顶部层：皇冠 ──
	var crown_base := TorusMesh.new(); crown_base.inner_radius = 0.26; crown_base.outer_radius = 0.030; crown_base.rings = 18; crown_base.ring_segments = 10
	_add_mesh(_top_node, crown_base, mat_gold, Vector3(0, 1.18, 0), Vector3(deg_to_rad(90), 0, 0))

	var crown_body := CylinderMesh.new(); crown_body.top_radius = 0.27; crown_body.bottom_radius = 0.29; crown_body.height = 0.20; crown_body.radial_segments = 16
	_add_mesh(_top_node, crown_body, mat_body, Vector3(0, 1.28, 0))

	# 皇冠五尖 Prism 环绕
	for i in 5:
		var ang2: float = i * TAU / 5.0
		var tip := PrismMesh.new(); tip.size = Vector3(0.10, 0.18, 0.10)
		var r: float = 0.20
		var mi_tip := _add_mesh(_top_node, tip, mat_gold, Vector3(cos(ang2) * r, 1.42, sin(ang2) * r), Vector3(deg_to_rad(90), -ang2, 0))
		mi_tip.name = "CrownTip%d" % i

	# 顶珠 Sphere —— 命名供死亡掉落动画
	var jewel_sphere := SphereMesh.new(); jewel_sphere.radius = 0.09; jewel_sphere.height = 0.18; jewel_sphere.radial_segments = 12; jewel_sphere.rings = 8
	var mi_jewel := _add_mesh(_top_node, jewel_sphere, mat_jewel, Vector3(0, 1.56, 0))
	mi_jewel.name = "CrownJewel"

	# 额前龙额饰 Box
	var forehead := BoxMesh.new(); forehead.size = Vector3(0.18, 0.08, 0.04)
	_add_mesh(_top_node, forehead, mat_gold, Vector3(0, 1.26, 0.26), Vector3.ZERO)


# ——— 2. 士仕 ADVISOR — 文官持笏，瘦长优雅 ———
func _build_advisor(is_red: bool) -> void:
	var mat_base := _mat_base
	var mat_body := _mat_body
	var mat_trim := _mat_trim
	var mat_robe := _make_mat(COL_IVORY if is_red else Color("#E8EBEF"), 0.08, 0.58)
	var mat_tablet := _make_mat(COL_IVORY, 0.06, 0.42) # 笏板 暖白
	mat_tablet.emission_enabled = false

	# 底座：小圆台
	var base_cyl := CylinderMesh.new(); base_cyl.top_radius = 0.34; base_cyl.bottom_radius = 0.38; base_cyl.height = 0.10; base_cyl.radial_segments = 16
	_add_mesh(_base_node, base_cyl, mat_base, Vector3(0, 0.05, 0))
	var base_ring := TorusMesh.new(); base_ring.inner_radius = 0.32; base_ring.outer_radius = 0.020; base_ring.rings = 16; base_ring.ring_segments = 10
	_add_mesh(_base_node, base_ring, mat_trim, Vector3(0, 0.105, 0), Vector3(deg_to_rad(90), 0, 0))
	# 底座玉带 Box
	var base_box := BoxMesh.new(); base_box.size = Vector3(0.42, 0.035, 0.42)
	_add_mesh(_base_node, base_box, mat_trim, Vector3(0, 0.12, 0), Vector3.ZERO)

	# 主体：瘦长身体 Capsule + 袍袖
	var body_capsule := CapsuleMesh.new(); body_capsule.radius = 0.17; body_capsule.height = 0.92; body_capsule.radial_segments = 14; body_capsule.rings = 6
	_add_mesh(_body_node, body_capsule, mat_body, Vector3(0, 0.62, 0))

	# 腰带
	var belt := TorusMesh.new(); belt.inner_radius = 0.18; belt.outer_radius = 0.022; belt.rings = 16; belt.ring_segments = 8
	_add_mesh(_body_node, belt, mat_trim, Vector3(0, 0.48, 0), Vector3(deg_to_rad(90), 0, 0))

	# 长袍前襟 Box 薄
	var robe_front := BoxMesh.new(); robe_front.size = Vector3(0.26, 0.72, 0.03)
	_add_mesh(_body_node, robe_front, mat_robe, Vector3(0, 0.62, 0.15), Vector3.ZERO)

	# 拂袖 左右 Box 薄片飘逸
	var sleeve_l := BoxMesh.new(); sleeve_l.size = Vector3(0.14, 0.46, 0.03)
	_add_mesh(_body_node, sleeve_l, mat_robe, Vector3(-0.24, 0.70, 0.05), Vector3(0, 0, deg_to_rad(18)))
	var sleeve_r := BoxMesh.new(); sleeve_r.size = Vector3(0.14, 0.46, 0.03)
	_add_mesh(_body_node, sleeve_r, mat_robe, Vector3(0.24, 0.70, 0.05), Vector3(0, 0, deg_to_rad(-18)))

	# 持笏 Box 竖直，置于胸前 —— 关键部件命名 Tablet 供击杀动画
	var tablet := BoxMesh.new(); tablet.size = Vector3(0.055, 0.58, 0.018)
	var mi_tablet := _add_mesh(_body_node, tablet, mat_tablet, Vector3(0, 0.72, 0.22), Vector3(deg_to_rad(8), 0, 0))
	mi_tablet.name = "Tablet"

	# 顶部：文官帽
	var head := SphereMesh.new(); head.radius = 0.13; head.height = 0.26; head.radial_segments = 12; head.rings = 8
	_add_mesh(_top_node, head, mat_robe, Vector3(0, 1.10, 0))

	var hat_brim := TorusMesh.new(); hat_brim.inner_radius = 0.14; hat_brim.outer_radius = 0.020; hat_brim.rings = 16; hat_brim.ring_segments = 8
	_add_mesh(_top_node, hat_brim, mat_trim, Vector3(0, 1.16, 0), Vector3(deg_to_rad(90), 0, 0))

	var hat_body := CylinderMesh.new(); hat_body.top_radius = 0.14; hat_body.bottom_radius = 0.155; hat_body.height = 0.18; hat_body.radial_segments = 14
	_add_mesh(_top_node, hat_body, mat_body, Vector3(0, 1.26, 0))

	# 帽翼 左右 Box 横展（乌纱帽翅）
	var wing_l := BoxMesh.new(); wing_l.size = Vector3(0.22, 0.02, 0.07)
	_add_mesh(_top_node, wing_l, mat_trim, Vector3(-0.24, 1.26, 0), Vector3(0, 0, deg_to_rad(6)))
	var wing_r := BoxMesh.new(); wing_r.size = Vector3(0.22, 0.02, 0.07)
	_add_mesh(_top_node, wing_r, mat_trim, Vector3(0.24, 1.26, 0), Vector3(0, 0, deg_to_rad(-6)))

	# 帽顶珠 Sphere
	var hat_top_sphere := SphereMesh.new(); hat_top_sphere.radius = 0.05; hat_top_sphere.height = 0.10; hat_top_sphere.radial_segments = 10; hat_top_sphere.rings = 6
	var mat_hat_jewel := _make_mat(COL_RED_JEWEL if is_red else COL_SILVER, 0.2, 0.28, COL_RED_JEWEL if is_red else COL_SILVER, 0.5)
	var mi_hat_jewel := _add_mesh(_top_node, hat_top_sphere, mat_hat_jewel, Vector3(0, 1.38, 0))
	mi_hat_jewel.name = "HatJewel"


# ——— 3. 象相 ELEPHANT — 巨象造型，象鼻象牙 ———
func _build_elephant(is_red: bool) -> void:
	var mat_base := _mat_base
	var mat_body := _mat_body
	var mat_trim := _mat_trim
	var mat_skin: StandardMaterial3D = _make_mat(Color("#7A6A5A") if is_red else Color("#5A5E66"), 0.10, 0.72)
	var mat_ivory := _make_mat(COL_IVORY, 0.04, 0.36)
	var mat_dark_skin := _make_mat(Color("#4A3F35"), 0.12, 0.68)

	# 底座：宽大厚重
	var base_cyl := CylinderMesh.new(); base_cyl.top_radius = 0.50; base_cyl.bottom_radius = 0.54; base_cyl.height = 0.12; base_cyl.radial_segments = 20
	_add_mesh(_base_node, base_cyl, mat_base, Vector3(0, 0.06, 0))
	var base_ring := TorusMesh.new(); base_ring.inner_radius = 0.47; base_ring.outer_radius = 0.024; base_ring.rings = 20; base_ring.ring_segments = 10
	_add_mesh(_base_node, base_ring, mat_trim, Vector3(0, 0.125, 0), Vector3(deg_to_rad(90), 0, 0))

	# 象腿 四根 Cylinder 粗壮
	var leg_positions: Array[Vector3] = [Vector3(-0.26, 0.33, -0.18), Vector3(0.26, 0.33, -0.18), Vector3(-0.26, 0.33, 0.18), Vector3(0.26, 0.33, 0.18)]
	for idx in leg_positions.size():
		var leg := CylinderMesh.new(); leg.top_radius = 0.075; leg.bottom_radius = 0.085; leg.height = 0.46; leg.radial_segments = 10
		var mi_leg := _add_mesh(_body_node, leg, mat_dark_skin, leg_positions[idx])
		mi_leg.name = "Leg%d" % idx
		# 蹄部 Torus
		var hoof := TorusMesh.new(); hoof.inner_radius = 0.06; hoof.outer_radius = 0.022; hoof.rings = 10; hoof.ring_segments = 8
		_add_mesh(_body_node, hoof, mat_base, leg_positions[idx] + Vector3(0, -0.22, 0), Vector3(deg_to_rad(90), 0, 0))

	# 象腹/象身 巨球 横向压扁
	var body_sphere := SphereMesh.new(); body_sphere.radius = 0.34; body_sphere.height = 0.68; body_sphere.radial_segments = 16; body_sphere.rings = 10
	var mi_body := _add_mesh(_body_node, body_sphere, mat_skin, Vector3(0, 0.58, 0), Vector3.ZERO, Vector3(1.15, 0.82, 0.95))
	mi_body.name = "ElephantBody"

	# 象背鞍 Box
	var saddle := BoxMesh.new(); saddle.size = Vector3(0.32, 0.07, 0.28)
	_add_mesh(_body_node, saddle, mat_trim, Vector3(0, 0.82, 0), Vector3.ZERO)
	# 鞍侧裙 Box
	var saddle_skirt_l := BoxMesh.new(); saddle_skirt_l.size = Vector3(0.03, 0.14, 0.24)
	_add_mesh(_body_node, saddle_skirt_l, mat_trim, Vector3(-0.20, 0.74, 0), Vector3.ZERO)
	var saddle_skirt_r := BoxMesh.new(); saddle_skirt_r.size = Vector3(0.03, 0.14, 0.24)
	_add_mesh(_body_node, saddle_skirt_r, mat_trim, Vector3(0.20, 0.74, 0), Vector3.ZERO)

	# 象头 Sphere 前置
	var head := SphereMesh.new(); head.radius = 0.20; head.height = 0.40; head.radial_segments = 14; head.rings = 8
	_add_mesh(_top_node, head, mat_skin, Vector3(0, 0.72, 0.34))

	# 象耳 左右 Box 大耳
	var ear_l := BoxMesh.new(); ear_l.size = Vector3(0.04, 0.26, 0.20)
	_add_mesh(_top_node, ear_l, mat_skin, Vector3(-0.22, 0.74, 0.28), Vector3(0, deg_to_rad(18), deg_to_rad(-12)))
	var ear_r := BoxMesh.new(); ear_r.size = Vector3(0.04, 0.26, 0.20)
	_add_mesh(_top_node, ear_r, mat_skin, Vector3(0.22, 0.74, 0.28), Vector3(0, deg_to_rad(-18), deg_to_rad(12)))

	# 象牙 Cylinder 圆锥形（上细下粗拟锥）左右 —— 命名供动画
	var tusk_l_mesh := CylinderMesh.new(); tusk_l_mesh.top_radius = 0.015; tusk_l_mesh.bottom_radius = 0.042; tusk_l_mesh.height = 0.38; tusk_l_mesh.radial_segments = 8
	var mi_tusk_l := _add_mesh(_top_node, tusk_l_mesh, mat_ivory, Vector3(-0.10, 0.60, 0.50), Vector3(deg_to_rad(68), 0, deg_to_rad(-18)))
	mi_tusk_l.name = "TuskL"
	var tusk_r_mesh := CylinderMesh.new(); tusk_r_mesh.top_radius = 0.015; tusk_r_mesh.bottom_radius = 0.042; tusk_r_mesh.height = 0.38; tusk_r_mesh.radial_segments = 8
	var mi_tusk_r := _add_mesh(_top_node, tusk_r_mesh, mat_ivory, Vector3(0.10, 0.60, 0.50), Vector3(deg_to_rad(68), 0, deg_to_rad(18)))
	mi_tusk_r.name = "TuskR"

	# 象鼻 多段 Capsule 拟弯曲 —— 主干 + 鼻头
	var trunk_seg1 := CapsuleMesh.new(); trunk_seg1.radius = 0.065; trunk_seg1.height = 0.28; trunk_seg1.radial_segments = 10; trunk_seg1.rings = 4
	var mi_trunk1 := _add_mesh(_top_node, trunk_seg1, mat_dark_skin, Vector3(0, 0.58, 0.56), Vector3(deg_to_rad(72), 0, 0))
	mi_trunk1.name = "Trunk"
	var trunk_seg2 := CapsuleMesh.new(); trunk_seg2.radius = 0.05; trunk_seg2.height = 0.22; trunk_seg2.radial_segments = 10; trunk_seg2.rings = 4
	_add_mesh(_top_node, trunk_seg2, mat_dark_skin, Vector3(0, 0.40, 0.68), Vector3(deg_to_rad(88), 0, 0))
	var trunk_tip := SphereMesh.new(); trunk_tip.radius = 0.045; trunk_tip.height = 0.09; trunk_tip.radial_segments = 10; trunk_tip.rings = 6
	_add_mesh(_top_node, trunk_tip, mat_dark_skin, Vector3(0, 0.30, 0.74))

	# 象眼 小黑珠
	var eye_mat := _make_mat(Color("#111111"), 0.0, 0.18)
	var eye_l := SphereMesh.new(); eye_l.radius = 0.028; eye_l.height = 0.056; eye_l.radial_segments = 8; eye_l.rings = 6
	_add_mesh(_top_node, eye_l, eye_mat, Vector3(-0.10, 0.76, 0.50))
	var eye_r := SphereMesh.new(); eye_r.radius = 0.028; eye_r.height = 0.056; eye_r.radial_segments = 8; eye_r.rings = 6
	_add_mesh(_top_node, eye_r, eye_mat, Vector3(0.10, 0.76, 0.50))

	# 尾巴 Capsule 后置
	var tail := CapsuleMesh.new(); tail.radius = 0.028; tail.height = 0.18; tail.radial_segments = 8; tail.rings = 4
	_add_mesh(_body_node, tail, mat_dark_skin, Vector3(0, 0.52, -0.40), Vector3(deg_to_rad(40), 0, 0))


# ——— 4. 马 HORSE — 烈马造型，马头鬃毛四蹄 ———
func _build_horse(is_red: bool) -> void:
	var mat_base := _mat_base
	var mat_body := _mat_body
	var mat_trim := _mat_trim
	var mat_horse: StandardMaterial3D = _make_mat(Color("#8B4513") if is_red else Color("#2B2E33"), 0.12, 0.62) # 马身棕/青黑
	var mat_mane: StandardMaterial3D = _make_mat(COL_MANE if is_red else COL_SILVER_DEEP, 0.08, 0.78)
	var mat_hoof: StandardMaterial3D = _make_mat(COL_BLACK_DEEP, 0.25, 0.55)

	# 底座 椭圆感
	var base_cyl := CylinderMesh.new(); base_cyl.top_radius = 0.42; base_cyl.bottom_radius = 0.46; base_cyl.height = 0.10; base_cyl.radial_segments = 18
	_add_mesh(_base_node, base_cyl, mat_base, Vector3(0, 0.05, 0))
	var base_ring := TorusMesh.new(); base_ring.inner_radius = 0.40; base_ring.outer_radius = 0.020; base_ring.rings = 18; base_ring.ring_segments = 10
	_add_mesh(_base_node, base_ring, mat_trim, Vector3(0, 0.108, 0), Vector3(deg_to_rad(90), 0, 0))

	# 马身 Box 横长
	var horse_body := BoxMesh.new(); horse_body.size = Vector3(0.52, 0.28, 0.26)
	_add_mesh(_body_node, horse_body, mat_horse, Vector3(0, 0.52, -0.04))

	# 马脖 Box 斜立
	var neck := BoxMesh.new(); neck.size = Vector3(0.18, 0.38, 0.15)
	_add_mesh(_body_node, neck, mat_horse, Vector3(0, 0.72, 0.16), Vector3(deg_to_rad(-18), 0, 0))

	# 马鞍 Box + 缰绳 Torus
	var saddle2 := BoxMesh.new(); saddle2.size = Vector3(0.30, 0.08, 0.24)
	_add_mesh(_body_node, saddle2, mat_trim, Vector3(0, 0.68, -0.04))
	var rein := TorusMesh.new(); rein.inner_radius = 0.16; rein.outer_radius = 0.012; rein.rings = 14; rein.ring_segments = 8
	_add_mesh(_body_node, rein, mat_trim, Vector3(0, 0.64, 0.12), Vector3(deg_to_rad(90), 0, 0))

	# 四蹄 Cylinder 竖立 —— 命名供奔跑时微动
	var leg_pos: Array[Vector3] = [Vector3(-0.16, 0.28, -0.12), Vector3(0.16, 0.28, -0.12), Vector3(-0.16, 0.28, 0.10), Vector3(0.16, 0.28, 0.10)]
	for i in leg_pos.size():
		var leg := CylinderMesh.new(); leg.top_radius = 0.038; leg.bottom_radius = 0.045; leg.height = 0.42; leg.radial_segments = 8
		var mi_leg := _add_mesh(_body_node, leg, mat_horse, leg_pos[i])
		mi_leg.name = "Leg%d" % i
		var hoof2 := CylinderMesh.new(); hoof2.top_radius = 0.048; hoof2.bottom_radius = 0.055; hoof2.height = 0.06; hoof2.radial_segments = 8
		_add_mesh(_body_node, hoof2, mat_hoof, leg_pos[i] + Vector3(0, -0.21, 0))

	# 马尾 Capsule 后飘
	var tail2 := CapsuleMesh.new(); tail2.radius = 0.055; tail2.height = 0.32; tail2.radial_segments = 8; tail2.rings = 4
	_add_mesh(_body_node, tail2, mat_mane, Vector3(0, 0.54, -0.32), Vector3(deg_to_rad(38), 0, 0))

	# ── 顶部：马头 + 鬃毛 ──
	# 马头 主 Box
	var head_box := BoxMesh.new(); head_box.size = Vector3(0.20, 0.20, 0.32)
	var mi_head := _add_mesh(_top_node, head_box, mat_horse, Vector3(0, 0.96, 0.34), Vector3.ZERO)
	mi_head.name = "HorseHead"

	# 马鼻 前端 Sphere
	var nose := SphereMesh.new(); nose.radius = 0.08; nose.height = 0.16; nose.radial_segments = 10; nose.rings = 6
	_add_mesh(_top_node, nose, mat_horse, Vector3(0, 0.92, 0.54), Vector3.ZERO, Vector3(1.2, 0.9, 1.0))

	# 马耳 Prism 三角
	var ear_lm := PrismMesh.new(); ear_lm.size = Vector3(0.07, 0.12, 0.07)
	_add_mesh(_top_node, ear_lm, mat_horse, Vector3(-0.07, 1.10, 0.28), Vector3(deg_to_rad(90), 0, deg_to_rad(22)))
	var ear_rm := PrismMesh.new(); ear_rm.size = Vector3(0.07, 0.12, 0.07)
	_add_mesh(_top_node, ear_rm, mat_horse, Vector3(0.07, 1.10, 0.28), Vector3(deg_to_rad(90), 0, deg_to_rad(-22)))

	# 鬃毛 Prism 多片立起
	for i in 4:
		var mane_seg := PrismMesh.new(); mane_seg.size = Vector3(0.06, 0.14, 0.08)
		var y_off: float = 0.86 + i * 0.07
		var z_off: float = 0.12 + i * 0.015
		var mi_mane := _add_mesh(_top_node, mane_seg, mat_mane, Vector3(0, y_off, z_off), Vector3(deg_to_rad(90), 0, 0))
		mi_mane.name = "Mane%d" % i

	# 缰绳衔铁 Box
	var bit := BoxMesh.new(); bit.size = Vector3(0.16, 0.02, 0.02)
	_add_mesh(_top_node, bit, mat_trim, Vector3(0, 0.92, 0.48))

	# 马眼 小球
	var eye_mat2 := _make_mat(Color("#0F0F0F"), 0.0, 0.12)
	var eye_l2 := SphereMesh.new(); eye_l2.radius = 0.022; eye_l2.height = 0.044; eye_l2.radial_segments = 8; eye_l2.rings = 6
	_add_mesh(_top_node, eye_l2, eye_mat2, Vector3(-0.11, 0.98, 0.42))
	var eye_r2 := SphereMesh.new(); eye_r2.radius = 0.022; eye_r2.height = 0.044; eye_r2.radial_segments = 8; eye_r2.rings = 6
	_add_mesh(_top_node, eye_r2, eye_mat2, Vector3(0.11, 0.98, 0.42))


# ——— 5. 车 CHARIOT — 战车形象，木轮+战旗 ———
# 行走：车轮滚动+扬尘；击杀：战车冲锋碾压；死亡：车体散架
func _build_chariot(is_red: bool) -> void:
	var mat_base := _mat_base
	var mat_body := _mat_body
	var mat_trim := _mat_trim
	var mat_wood := _make_mat(COL_WOOD, 0.12, 0.58)
	var mat_iron := _make_mat(COL_STEEL, 0.55, 0.32)

	# 底盘 Box 厚重
	var chassis := BoxMesh.new(); chassis.size = Vector3(0.68, 0.12, 0.48)
	_add_mesh(_base_node, chassis, mat_wood, Vector3(0, 0.08, 0))
	# 底盘包边 Box
	var chassis_rim := BoxMesh.new(); chassis_rim.size = Vector3(0.72, 0.04, 0.52)
	_add_mesh(_base_node, chassis_rim, mat_trim, Vector3(0, 0.145, 0))

	# 车轴 Cylinder 横杆
	var axle_f := CylinderMesh.new(); axle_f.top_radius = 0.022; axle_f.bottom_radius = 0.022; axle_f.height = 0.64; axle_f.radial_segments = 10
	_add_mesh(_base_node, axle_f, mat_iron, Vector3(0, 0.16, 0.16), Vector3(0, 0, deg_to_rad(90)))
	var axle_b := CylinderMesh.new(); axle_b.top_radius = 0.022; axle_b.bottom_radius = 0.022; axle_b.height = 0.64; axle_b.radial_segments = 10
	_add_mesh(_base_node, axle_b, mat_iron, Vector3(0, 0.16, -0.16), Vector3(0, 0, deg_to_rad(90)))

	# 车轮 Torus 竖立左右 — 命名 WheelL/R 供滚动动画
	var wheel_l_f := TorusMesh.new(); wheel_l_f.inner_radius = 0.15; wheel_l_f.outer_radius = 0.032; wheel_l_f.rings = 16; wheel_l_f.ring_segments = 10
	var mi_wlf := _add_mesh(_base_node, wheel_l_f, mat_iron, Vector3(-0.34, 0.16, 0.16), Vector3(deg_to_rad(90), 0, 0))
	mi_wlf.name = "WheelLF"
	var wheel_r_f := TorusMesh.new(); wheel_r_f.inner_radius = 0.15; wheel_r_f.outer_radius = 0.032; wheel_r_f.rings = 16; wheel_r_f.ring_segments = 10
	var mi_wrf := _add_mesh(_base_node, wheel_r_f, mat_iron, Vector3(0.34, 0.16, 0.16), Vector3(deg_to_rad(90), 0, 0))
	mi_wrf.name = "WheelRF"
	var wheel_l_b := TorusMesh.new(); wheel_l_b.inner_radius = 0.15; wheel_l_b.outer_radius = 0.032; wheel_l_b.rings = 16; wheel_l_b.ring_segments = 10
	var mi_wlb := _add_mesh(_base_node, wheel_l_b, mat_iron, Vector3(-0.34, 0.16, -0.16), Vector3(deg_to_rad(90), 0, 0))
	mi_wlb.name = "WheelLB"
	var wheel_r_b := TorusMesh.new(); wheel_r_b.inner_radius = 0.15; wheel_r_b.outer_radius = 0.032; wheel_r_b.rings = 16; wheel_r_b.ring_segments = 10
	var mi_wrb := _add_mesh(_base_node, wheel_r_b, mat_iron, Vector3(0.34, 0.16, -0.16), Vector3(deg_to_rad(90), 0, 0))
	mi_wrb.name = "WheelRB"
	# 轮毂 Sphere
	for pos in [Vector3(-0.34, 0.16, 0.16), Vector3(0.34, 0.16, 0.16), Vector3(-0.34, 0.16, -0.16), Vector3(0.34, 0.16, -0.16)]:
		var hub := SphereMesh.new(); hub.radius = 0.038; hub.height = 0.076; hub.radial_segments = 8; hub.rings = 6
		_add_mesh(_base_node, hub, mat_trim, pos)

	# ── 车厢 Body ──
	# 厢底 Box
	var carriage_floor := BoxMesh.new(); carriage_floor.size = Vector3(0.52, 0.05, 0.38)
	_add_mesh(_body_node, carriage_floor, mat_wood, Vector3(0, 0.24, 0))
	# 厢壁 前后左右 Box 薄墙
	var wall_front := BoxMesh.new(); wall_front.size = Vector3(0.52, 0.28, 0.03)
	_add_mesh(_body_node, wall_front, mat_body, Vector3(0, 0.40, 0.185))
	var wall_back := BoxMesh.new(); wall_back.size = Vector3(0.52, 0.28, 0.03)
	_add_mesh(_body_node, wall_back, mat_body, Vector3(0, 0.40, -0.185))
	var wall_left := BoxMesh.new(); wall_left.size = Vector3(0.03, 0.28, 0.38)
	_add_mesh(_body_node, wall_left, mat_body, Vector3(-0.25, 0.40, 0))
	var wall_right := BoxMesh.new(); wall_right.size = Vector3(0.03, 0.28, 0.38)
	_add_mesh(_body_node, wall_right, mat_body, Vector3(0.25, 0.40, 0))

	# 车辕 Box 长杆向前
	var shaft := BoxMesh.new(); shaft.size = Vector3(0.06, 0.04, 0.42)
	_add_mesh(_body_node, shaft, mat_wood, Vector3(0, 0.32, 0.42), Vector3.ZERO)

	# 顶部：战旗
	var flag_pole := CylinderMesh.new(); flag_pole.top_radius = 0.015; flag_pole.bottom_radius = 0.018; flag_pole.height = 0.62; flag_pole.radial_segments = 8
	_add_mesh(_top_node, flag_pole, mat_trim, Vector3(0, 0.70, -0.12))
	var flag_cloth := BoxMesh.new(); flag_cloth.size = Vector3(0.36, 0.28, 0.02)
	var flag_col: Color = COL_RED_PRIMARY if is_red else COL_BLACK_PRIMARY
	var mat_flag := _make_mat(flag_col, 0.18, 0.52)
	_add_mesh(_top_node, flag_cloth, mat_flag, Vector3(0.18, 0.84, -0.12), Vector3(0, deg_to_rad(6), deg_to_rad(4)))
	# 旗顶矛头 Prism
	var flag_tip := PrismMesh.new(); flag_tip.size = Vector3(0.08, 0.10, 0.08)
	_add_mesh(_top_node, flag_tip, mat_trim, Vector3(0, 1.04, -0.12), Vector3(deg_to_rad(180), 0, 0))
	# 旗面纹章 Torus 圆徽
	var emblem := TorusMesh.new(); emblem.inner_radius = 0.05; emblem.outer_radius = 0.012; emblem.rings = 12; emblem.ring_segments = 8
	_add_mesh(_top_node, emblem, mat_trim, Vector3(0.18, 0.84, -0.10), Vector3(deg_to_rad(90), 0, 0))


# ——— 6. 炮 CANNON — 火炮造型，炮管炮架 ———
func _build_cannon(is_red: bool) -> void:
	var mat_base := _mat_base
	var mat_body := _mat_body
	var mat_trim := _mat_trim
	var mat_iron := _make_mat(Color("#3A3E44"), 0.56, 0.34)
	var mat_wood2 := _make_mat(COL_WOOD, 0.12, 0.58)
	var mat_brass := _make_mat(COL_BRONZE if is_red else COL_STEEL, 0.58, 0.32, COL_BRONZE if is_red else COL_STEEL, 0.16)

	# 底座：炮架底板 Box
	var base_plate := BoxMesh.new(); base_plate.size = Vector3(0.52, 0.08, 0.36)
	_add_mesh(_base_node, base_plate, mat_wood2, Vector3(0, 0.06, 0))
	var base_rim := BoxMesh.new(); base_rim.size = Vector3(0.54, 0.025, 0.38)
	_add_mesh(_base_node, base_rim, mat_trim, Vector3(0, 0.108, 0))

	# 炮轮 左右 Torus/Cylinder
	var wheel_l := CylinderMesh.new(); wheel_l.top_radius = 0.13; wheel_l.bottom_radius = 0.13; wheel_l.height = 0.04; wheel_l.radial_segments = 14
	var mi_wl := _add_mesh(_base_node, wheel_l, mat_iron, Vector3(-0.30, 0.13, 0), Vector3(0, 0, deg_to_rad(90)))
	mi_wl.name = "WheelL"
	var wheel_r := CylinderMesh.new(); wheel_r.top_radius = 0.13; wheel_r.bottom_radius = 0.13; wheel_r.height = 0.04; wheel_r.radial_segments = 14
	var mi_wr := _add_mesh(_base_node, wheel_r, mat_iron, Vector3(0.30, 0.13, 0), Vector3(0, 0, deg_to_rad(90)))
	mi_wr.name = "WheelR"
	# 轮毂 Torus 装饰
	var hub_l := TorusMesh.new(); hub_l.inner_radius = 0.045; hub_l.outer_radius = 0.015; hub_l.rings = 12; hub_l.ring_segments = 8
	_add_mesh(_base_node, hub_l, mat_trim, Vector3(-0.30, 0.13, 0), Vector3(deg_to_rad(90), 0, 0))
	var hub_r := TorusMesh.new(); hub_r.inner_radius = 0.045; hub_r.outer_radius = 0.015; hub_r.rings = 12; hub_r.ring_segments = 8
	_add_mesh(_base_node, hub_r, mat_trim, Vector3(0.30, 0.13, 0), Vector3(deg_to_rad(90), 0, 0))

	# 炮架侧板 Box 左右
	var frame_l := BoxMesh.new(); frame_l.size = Vector3(0.08, 0.28, 0.34)
	_add_mesh(_body_node, frame_l, mat_wood2, Vector3(-0.18, 0.30, 0))
	var frame_r := BoxMesh.new(); frame_r.size = Vector3(0.08, 0.28, 0.34)
	_add_mesh(_body_node, frame_r, mat_wood2, Vector3(0.18, 0.30, 0))

	# 横梁 Cylinder
	var cross_beam := CylinderMesh.new(); cross_beam.top_radius = 0.02; cross_beam.bottom_radius = 0.02; cross_beam.height = 0.36; cross_beam.radial_segments = 8
	_add_mesh(_body_node, cross_beam, mat_iron, Vector3(0, 0.22, 0.10), Vector3(0, 0, deg_to_rad(90)))

	# 炮管 Cylinder 横躺，前后向（沿 Z）—— 核心部件 Barrel
	var barrel := CylinderMesh.new(); barrel.top_radius = 0.095; barrel.bottom_radius = 0.11; barrel.height = 0.62; barrel.radial_segments = 16
	var mi_barrel := _add_mesh(_body_node, barrel, mat_iron, Vector3(0, 0.38, 0.08), Vector3(deg_to_rad(90), 0, 0))
	mi_barrel.name = "Barrel"

	# 炮箍 Torus 两个
	var hoop1 := TorusMesh.new(); hoop1.inner_radius = 0.098; hoop1.outer_radius = 0.018; hoop1.rings = 14; hoop1.ring_segments = 8
	_add_mesh(_body_node, hoop1, mat_brass, Vector3(0, 0.38, -0.06), Vector3(deg_to_rad(90), 0, 0))
	var hoop2 := TorusMesh.new(); hoop2.inner_radius = 0.092; hoop2.outer_radius = 0.016; hoop2.rings = 14; hoop2.ring_segments = 8
	_add_mesh(_body_node, hoop2, mat_brass, Vector3(0, 0.38, 0.18), Vector3(deg_to_rad(90), 0, 0))

	# 炮口前端 Torus 加厚
	var muzzle_ring := TorusMesh.new(); muzzle_ring.inner_radius = 0.095; muzzle_ring.outer_radius = 0.022; muzzle_ring.rings = 14; muzzle_ring.ring_segments = 8
	_add_mesh(_body_node, muzzle_ring, mat_brass, Vector3(0, 0.38, 0.38), Vector3(deg_to_rad(90), 0, 0))

	# 炮闩 Sphere 后端
	var breech := SphereMesh.new(); breech.radius = 0.09; breech.height = 0.18; breech.radial_segments = 10; breech.rings = 6
	_add_mesh(_body_node, breech, mat_iron, Vector3(0, 0.38, -0.24))

	# 瞄具 Box 顶部
	var sight := BoxMesh.new(); sight.size = Vector3(0.06, 0.06, 0.10)
	_add_mesh(_top_node, sight, mat_trim, Vector3(0, 0.50, -0.06))

	# 火门（点火孔）小 Sphere
	var vent_mat := _make_mat(Color("#1A1A1E"), 0.4, 0.45)
	var vent := SphereMesh.new(); vent.radius = 0.020; vent.height = 0.04; vent.radial_segments = 8; vent.rings = 6
	_add_mesh(_top_node, vent, vent_mat, Vector3(0, 0.48, -0.02))


# ——— 7. 兵卒 PAWN — 持矛步兵，盔甲盾牌感 ———
func _build_pawn(is_red: bool) -> void:
	var mat_base := _mat_base
	var mat_body := _mat_body
	var mat_trim := _mat_trim
	var mat_armor: StandardMaterial3D = _make_mat(Color("#8E95A0") if is_red else Color("#6B7280"), 0.45, 0.38) # 盔甲铁灰
	var mat_shield_col: Color = COL_RED_PRIMARY if is_red else COL_BLACK_PRIMARY
	var mat_shield := _make_mat(mat_shield_col, 0.22, 0.44)
	var mat_spear_shaft := _make_mat(Color("#6B4A2A"), 0.06, 0.72)
	var mat_spear_head := _make_mat(COL_SILVER, 0.72, 0.24, COL_SILVER, 0.12)

	# 底座
	var base_cyl := CylinderMesh.new(); base_cyl.top_radius = 0.32; base_cyl.bottom_radius = 0.36; base_cyl.height = 0.09; base_cyl.radial_segments = 16
	_add_mesh(_base_node, base_cyl, mat_base, Vector3(0, 0.045, 0))
	var base_ring := TorusMesh.new(); base_ring.inner_radius = 0.30; base_ring.outer_radius = 0.018; base_ring.rings = 16; base_ring.ring_segments = 8
	_add_mesh(_base_node, base_ring, mat_trim, Vector3(0, 0.095, 0), Vector3(deg_to_rad(90), 0, 0))

	# 下身 腿/裙甲 Box
	var skirt := BoxMesh.new(); skirt.size = Vector3(0.30, 0.22, 0.22)
	_add_mesh(_body_node, skirt, mat_armor, Vector3(0, 0.24, 0))
	var leg_l := BoxMesh.new(); leg_l.size = Vector3(0.09, 0.18, 0.10)
	_add_mesh(_body_node, leg_l, mat_armor, Vector3(-0.09, 0.14, 0))
	var leg_r := BoxMesh.new(); leg_r.size = Vector3(0.09, 0.18, 0.10)
	_add_mesh(_body_node, leg_r, mat_armor, Vector3(0.09, 0.14, 0))

	# 胸甲 Box
	var chest := BoxMesh.new(); chest.size = Vector3(0.28, 0.32, 0.18)
	_add_mesh(_body_node, chest, mat_body, Vector3(0, 0.48, 0))
	# 胸前护心镜 Torus 圆盾徽
	var chest_badge := TorusMesh.new(); chest_badge.inner_radius = 0.055; chest_badge.outer_radius = 0.014; chest_badge.rings = 12; chest_badge.ring_segments = 8
	_add_mesh(_body_node, chest_badge, mat_trim, Vector3(0, 0.50, 0.10), Vector3(deg_to_rad(0), 0, 0))
	var badge_center := CylinderMesh.new(); badge_center.top_radius = 0.055; badge_center.bottom_radius = 0.055; badge_center.height = 0.012; badge_center.radial_segments = 12
	var badge_col: Color = COL_RED_GOLD if is_red else COL_SILVER
	var mat_badge := _make_mat(badge_col, 0.62, 0.30, badge_col, 0.35)
	_add_mesh(_body_node, badge_center, mat_badge, Vector3(0, 0.50, 0.108), Vector3(deg_to_rad(90), 0, 0))

	# 盾牌 Box 竖盾，置于左前
	var shield := BoxMesh.new(); shield.size = Vector3(0.24, 0.34, 0.03)
	var mi_shield := _add_mesh(_body_node, shield, mat_shield, Vector3(-0.20, 0.46, 0.14), Vector3(0, deg_to_rad(18), 0))
	mi_shield.name = "Shield"
	# 盾面 boss Sphere 凸起
	var shield_boss := SphereMesh.new(); shield_boss.radius = 0.045; shield_boss.height = 0.09; shield_boss.radial_segments = 8; shield_boss.rings = 6
	_add_mesh(_body_node, shield_boss, mat_trim, Vector3(-0.20, 0.46, 0.165))

	# 腰带 Torus
	var belt2 := TorusMesh.new(); belt2.inner_radius = 0.17; belt2.outer_radius = 0.020; belt2.rings = 14; belt2.ring_segments = 8
	_add_mesh(_body_node, belt2, mat_trim, Vector3(0, 0.34, 0), Vector3(deg_to_rad(90), 0, 0))

	# 头部 Sphere
	var head2 := SphereMesh.new(); head2.radius = 0.12; head2.height = 0.24; head2.radial_segments = 12; head2.rings = 8
	var mat_skin2 := _make_mat(Color("#E8C9A0"), 0.0, 0.62)
	_add_mesh(_top_node, head2, mat_skin2, Vector3(0, 0.72, 0))

	# 头盔 Sphere 半球
	var helmet := SphereMesh.new(); helmet.radius = 0.15; helmet.height = 0.30; helmet.radial_segments = 14; helmet.rings = 8
	var mat_helmet := _make_mat(mat_armor.albedo_color, 0.48, 0.36)
	_add_mesh(_top_node, helmet, mat_helmet, Vector3(0, 0.78, 0), Vector3.ZERO, Vector3(1.0, 0.78, 1.0))

	# 盔缨 Capsule 红缨 / 黑缨
	var plume_col: Color = COL_RED_JEWEL if is_red else Color("#2A2E33")
	var mat_plume := _make_mat(plume_col, 0.12, 0.62)
	var plume := CapsuleMesh.new(); plume.radius = 0.032; plume.height = 0.14; plume.radial_segments = 8; plume.rings = 4
	_add_mesh(_top_node, plume, mat_plume, Vector3(0, 0.94, 0))

	# 盔沿 Box 帽檐
	var helm_brim := BoxMesh.new(); helm_brim.size = Vector3(0.28, 0.02, 0.14)
	_add_mesh(_top_node, helm_brim, mat_trim, Vector3(0, 0.70, 0.06))

	# 长矛：矛杆 Cylinder 竖直 + 矛头 Prism
	var spear_shaft := CylinderMesh.new(); spear_shaft.top_radius = 0.014; spear_shaft.bottom_radius = 0.016; spear_shaft.height = 0.78; spear_shaft.radial_segments = 8
	var mi_shaft := _add_mesh(_top_node, spear_shaft, mat_spear_shaft, Vector3(0.18, 0.62, 0.10))
	mi_shaft.name = "Spear"
	var spear_head_mesh := PrismMesh.new(); spear_head_mesh.size = Vector3(0.09, 0.18, 0.02)
	var mi_spear_head := _add_mesh(_top_node, spear_head_mesh, mat_spear_head, Vector3(0.18, 1.08, 0.10), Vector3(deg_to_rad(90), 0, 0))
	mi_spear_head.name = "SpearHead"
	# 矛缨 Box 小布条
	var tassel := BoxMesh.new(); tassel.size = Vector3(0.05, 0.10, 0.02)
	var mat_tassel := _make_mat(COL_RED_JEWEL if is_red else COL_SILVER, 0.15, 0.42)
	_add_mesh(_top_node, tassel, mat_tassel, Vector3(0.18, 0.96, 0.10), Vector3.ZERO)


# ─────────────────────────────────────────────────────────────
# 动画：待机 / 移动 / 击杀 / 死亡 / 选中高亮
# ─────────────────────────────────────────────────────────────

## 待机微动：按棋子类型差异化循环浮动
func play_idle() -> void:
	if not is_inside_tree() or _root_visual == null or not is_instance_valid(_root_visual):
		return
	_stop_idle()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.set_loops(0) # 无限循环
	_idle_tween = tw

	match _piece_type:
		KING:
			# 御驾呼吸：缓慢上下 + 微弱威严摆动（y 与 rotation 同步）
			tw.tween_property(_root_visual, "position:y", 0.028, 1.6)
			tw.parallel().tween_property(_root_visual, "rotation:z", deg_to_rad(1.0), 1.6)
			tw.tween_property(_root_visual, "position:y", 0.0, 1.6)
			tw.parallel().tween_property(_root_visual, "rotation:z", deg_to_rad(-1.0), 1.6)
		ADVISOR:
			# 拂袖飘逸：优雅浮动 + 笏板轻摆
			var tablet := _body_node.get_node_or_null("Tablet") as MeshInstance3D
			tw.tween_property(_root_visual, "position:y", 0.035, 1.45)
			tw.parallel().tween_property(_body_node, "rotation:z", deg_to_rad(1.8), 1.45)
			if tablet != null:
				tw.parallel().tween_property(tablet, "rotation:x", deg_to_rad(6), 1.45)
			tw.tween_property(_root_visual, "position:y", 0.0, 1.45)
			tw.parallel().tween_property(_body_node, "rotation:z", deg_to_rad(-1.8), 1.45)
			if tablet != null:
				tw.parallel().tween_property(tablet, "rotation:x", deg_to_rad(-2), 1.45)
		ELEPHANT:
			# 沉重呼吸：慢、大、鼻尖轻摆
			var trunk := _top_node.get_node_or_null("Trunk") as MeshInstance3D
			tw.tween_property(_root_visual, "position:y", 0.016, 2.0)
			if trunk != null:
				tw.parallel().tween_property(trunk, "rotation:z", deg_to_rad(4), 2.0)
			tw.tween_property(_root_visual, "position:y", 0.0, 2.0)
			if trunk != null:
				tw.parallel().tween_property(trunk, "rotation:z", deg_to_rad(-4), 2.0)
		HORSE:
			# 烈马：颠簸感，马头轻点，鬃毛抖动
			var hhead := _top_node.get_node_or_null("HorseHead") as MeshInstance3D
			tw.tween_property(_root_visual, "position:y", 0.022, 0.9)
			if hhead != null:
				tw.parallel().tween_property(hhead, "rotation:x", deg_to_rad(5), 0.9)
			tw.tween_property(_root_visual, "position:y", 0.0, 0.9)
			if hhead != null:
				tw.parallel().tween_property(hhead, "rotation:x", 0.0, 0.9)
		CHARIOT:
			# 战车：轻微引擎震动，轮子微颤
			tw.tween_property(_root_visual, "position:y", 0.012, 1.15)
			tw.parallel().tween_property(_root_visual, "position:z", 0.008, 0.58)
			tw.tween_property(_root_visual, "position:y", 0.0, 1.15)
			tw.parallel().tween_property(_root_visual, "position:z", -0.008, 0.58)
			# 归位一帧，保证循环平滑
			tw.tween_property(_root_visual, "position:z", 0.0, 0.20)
		CANNON:
			# 火炮：炮管轻微俯仰瞄准
			var barrel := _body_node.get_node_or_null("Barrel") as MeshInstance3D
			tw.tween_property(_root_visual, "position:y", 0.010, 1.35)
			if barrel != null:
				tw.parallel().tween_property(barrel, "rotation:x", deg_to_rad(1.6), 1.35)
			tw.tween_property(_root_visual, "position:y", 0.0, 1.35)
			if barrel != null:
				tw.parallel().tween_property(barrel, "rotation:x", deg_to_rad(-1.2), 1.35)
		PAWN:
			# 步兵：持矛轻颤，盾牌微摆
			var spear := _top_node.get_node_or_null("SpearHead") as MeshInstance3D
			tw.tween_property(_root_visual, "position:y", 0.018, 1.12)
			if spear != null:
				tw.parallel().tween_property(spear, "position:y", 0.015, 1.12)
			tw.tween_property(_root_visual, "position:y", 0.0, 1.12)
			if spear != null:
				tw.parallel().tween_property(spear, "position:y", 0.0, 1.12)
		_:
			tw.tween_property(_root_visual, "position:y", 0.02, 1.4)
			tw.tween_property(_root_visual, "position:y", 0.0, 1.4)

## 移动动画：抛物位移 + 按类型差异化的姿态
## spec: play_move(to, duration) — 兼容旧的三参 play_move(from, to, duration)，内部自动适配 Vector2i/Vector3
## 返回 Tween 供外部 await tween.finished
func play_move(to_or_from, to_or_duration = null, duration_maybe = null) -> Tween:
	# 兼容双签名：setup 要求的 play_move(to, duration) 与旧的 play_move(from, to, duration)
	var from_pos: Vector3
	var to_pos: Vector3
	var duration: float = 0.42
	if duration_maybe != null:
		# 三参调用：from, to, duration
		from_pos = to_or_from as Vector3 if to_or_from is Vector3 else Vector3.ZERO
		to_pos = to_or_duration as Vector3 if to_or_duration is Vector3 else Vector3.ZERO
		# 处理 Vector2i 传入的兼容
		if to_or_from is Vector2i:
			from_pos = Vector3((to_or_from.x - 4) * 1.0, 0.22, (to_or_from.y - 4.5) * 1.0)
		if to_or_duration is Vector2i:
			to_pos = Vector3((to_or_duration.x - 4) * 1.0, 0.22, (to_or_duration.y - 4.5) * 1.0)
		duration = float(duration_maybe)
	elif to_or_duration != null:
		if to_or_duration is Vector3 and to_or_from is Vector3:
			from_pos = to_or_from
			to_pos = to_or_duration
			duration = 0.42
		elif (to_or_duration is float or to_or_duration is int) and (to_or_from is Vector3 or to_or_from is Vector2i or to_or_from is Vector2):
			# 双参：to, duration  (spec)
			from_pos = position
			if to_or_from is Vector3:
				to_pos = to_or_from
			elif to_or_from is Vector2i:
				to_pos = Vector3((to_or_from.x - 4) * 1.0, 0.22, (to_or_from.y - 4.5) * 1.0)
			elif to_or_from is Vector2:
				to_pos = Vector3(to_or_from.x, 0.22, to_or_from.y)
			else:
				to_pos = Vector3.ZERO
			duration = float(to_or_duration)
		elif to_or_duration is Vector3:
			from_pos = position
			to_pos = to_or_duration
			duration = 0.42
		else:
			from_pos = position
			to_pos = to_or_from as Vector3 if to_or_from is Vector3 else position
			duration = 0.42
	else:
		# 单参：仅 to
		from_pos = position
		if to_or_from is Vector3:
			to_pos = to_or_from
		elif to_or_from is Vector2i:
			to_pos = Vector3((to_or_from.x - 4) * 1.0, 0.22, (to_or_from.y - 4.5) * 1.0)
		elif to_or_from is Vector2:
			to_pos = Vector3(to_or_from.x, 0.22, to_or_from.y)
		else:
			to_pos = Vector3.ZERO
			duration = 0.42
	_stop_idle()
	_kill_move_tween()
	position = from_pos
	# 重置视觉姿态
	_root_visual.position = Vector3.ZERO
	_root_visual.rotation = Vector3.ZERO
	_root_visual.scale = Vector3.ONE
	_base_node.position = Vector3.ZERO; _base_node.rotation = Vector3.ZERO; _base_node.scale = Vector3.ONE
	_body_node.position = Vector3.ZERO; _body_node.rotation = Vector3.ZERO; _body_node.scale = Vector3.ONE
	_top_node.position = Vector3.ZERO; _top_node.rotation = Vector3.ZERO; _top_node.scale = Vector3.ONE

	var dur: float = maxf(duration, 0.12)
	var jump_h: float = _move_jump_height()

	# 主位移抛物 Tween（控制 self.position）
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(p: float) -> void:
		var base: Vector3 = from_pos.lerp(to_pos, p)
		# 基础抛物
		base.y += sin(p * PI) * jump_h
		# 类型相关的额外波动（包络在 sin 内，避免起点终点突变）
		var extra: float = 0.0
		if _piece_type == HORSE:
			# 马：三段颠簸
			extra = sin(p * PI * 3.0) * 0.045 * sin(p * PI)
		elif _piece_type == ELEPHANT:
			extra = sin(p * PI * 2.0) * 0.028 * sin(p * PI)
		elif _piece_type == PAWN:
			extra = sin(p * PI * 2.0) * 0.012
		base.y += extra
		position = base
	, 0.0, 1.0, dur)
	_move_tween = tw

	# 并行姿态 Tween（控制 _root_visual / 子部件）
	var pose := create_tween()
	_pose_tween = pose
	pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	match _piece_type:
		KING:
			# 御驾突进：蓄力后撤 + 剑气横摆 + 落地鼓胀
			pose.tween_property(_root_visual, "position:z", -0.06, dur * 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pose.tween_property(_root_visual, "rotation:y", deg_to_rad(10), dur * 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.06, 0.96, 1.06), dur * 0.18)
			pose.tween_property(_root_visual, "rotation:y", deg_to_rad(-7), dur * 0.30)
			pose.parallel().tween_property(_root_visual, "position:z", 0.0, dur * 0.30)
			pose.tween_property(_root_visual, "rotation:y", 0.0, dur * 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.14, 0.88, 1.14), dur * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pose.tween_property(_root_visual, "scale", Vector3.ONE, dur * 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			# 顶珠微旋
			var jewel := _top_node.get_node_or_null("CrownJewel") as MeshInstance3D
			if jewel != null:
				pose.parallel().tween_property(jewel, "rotation:y", deg_to_rad(80), dur * 0.55)
				pose.tween_property(jewel, "rotation:y", 0.0, dur * 0.25)
		ADVISOR:
			# 拂袖：S 形飘逸，身体左右倾摆
			pose.tween_property(_root_visual, "rotation:z", deg_to_rad(-9), dur * 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			pose.tween_property(_root_visual, "rotation:z", deg_to_rad(9), dur * 0.36)
			pose.tween_property(_root_visual, "rotation:z", 0.0, dur * 0.28)
			pose.parallel().tween_property(_body_node, "position:y", 0.05, dur * 0.22)
			pose.tween_property(_body_node, "position:y", 0.0, dur * 0.28)
			var tablet2 := _body_node.get_node_or_null("Tablet") as MeshInstance3D
			if tablet2 != null:
				pose.parallel().tween_property(tablet2, "rotation:z", deg_to_rad(12), dur * 0.30)
				pose.tween_property(tablet2, "rotation:z", 0.0, dur * 0.32)
		ELEPHANT:
			# 沉重踏步：两段重踏，scale 踩压感
			pose.tween_property(_root_visual, "scale", Vector3(1.04, 0.92, 1.04), dur * 0.22)
			pose.tween_property(_root_visual, "scale", Vector3(0.98, 1.04, 0.98), dur * 0.20)
			pose.tween_property(_root_visual, "scale", Vector3(1.03, 0.93, 1.03), dur * 0.22)
			pose.tween_property(_root_visual, "scale", Vector3.ONE, dur * 0.30).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "rotation:z", deg_to_rad(3.5), dur * 0.28)
			pose.tween_property(_root_visual, "rotation:z", deg_to_rad(-3.5), dur * 0.32)
			pose.tween_property(_root_visual, "rotation:z", 0.0, dur * 0.30)
			var trunk2 := _top_node.get_node_or_null("Trunk") as MeshInstance3D
			if trunk2 != null:
				pose.parallel().tween_property(trunk2, "rotation:x", deg_to_rad(14), dur * 0.35)
				pose.tween_property(trunk2, "rotation:x", 0.0, dur * 0.40)
		HORSE:
			# 奔跑跳跃：扬蹄前倾，鬃毛飘动，落地反弹
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(-16), dur * 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.03, 0.96, 1.03), dur * 0.24)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(8), dur * 0.30)
			pose.tween_property(_root_visual, "rotation:x", 0.0, dur * 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.10, 0.86, 1.10), dur * 0.12)
			pose.tween_property(_root_visual, "scale", Vector3.ONE, dur * 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			var hhead2 := _top_node.get_node_or_null("HorseHead") as MeshInstance3D
			if hhead2 != null:
				pose.parallel().tween_property(hhead2, "rotation:x", deg_to_rad(-10), dur * 0.28)
				pose.tween_property(hhead2, "rotation:x", 0.0, dur * 0.42)
			# 腿部小幅摆动模拟跑步
			for i in 4:
				var leg2 := _body_node.get_node_or_null("Leg%d" % i) as MeshInstance3D
				if leg2 != null:
					pose.parallel().tween_property(leg2, "rotation:x", deg_to_rad(18 if i % 2 == 0 else -18), dur * 0.22)
					pose.tween_property(leg2, "rotation:x", 0.0, dur * 0.45)
		CHARIOT:
			# 直线冲锋：前倾碾压，轮子狂转，到点急刹
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(11), dur * 0.20)
			pose.parallel().tween_property(_root_visual, "position:y", -0.02, dur * 0.20)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(2), dur * 0.45)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(-6), dur * 0.12)
			pose.tween_property(_root_visual, "rotation:x", 0.0, dur * 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.08, 0.95, 1.02), dur * 0.12)
			pose.tween_property(_root_visual, "scale", Vector3.ONE, dur * 0.28)
			# 轮子快速滚动（绕 X 旋转模拟，需将 Torus 视为滚轮，外观上用 rotation:x 转动）
			for wn in ["WheelLF", "WheelRF", "WheelLB", "WheelRB"]:
				var w := _base_node.get_node_or_null(wn) as MeshInstance3D
				if w != null:
					pose.parallel().tween_property(w, "rotation:y", deg_to_rad(720), dur * 0.88).set_trans(Tween.TRANS_LINEAR)
		CANNON:
			# 后坐发射：先小后坐蓄力，再猛冲，炮管冲击缩放
			pose.tween_property(_root_visual, "position:z", -0.10, dur * 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(0.96, 1.02, 0.96), dur * 0.14)
			pose.tween_property(_root_visual, "position:z", 0.07, dur * 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.04, 0.96, 1.04), dur * 0.14)
			pose.tween_property(_root_visual, "position:z", 0.0, dur * 0.38).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3.ONE, dur * 0.38)
			var barrel2 := _body_node.get_node_or_null("Barrel") as MeshInstance3D
			if barrel2 != null:
				pose.parallel().tween_property(barrel2, "position:z", -0.08, dur * 0.14)
				pose.tween_property(barrel2, "position:z", 0.0, dur * 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				pose.parallel().tween_property(barrel2, "scale:z", 0.86, dur * 0.12)
				pose.tween_property(barrel2, "scale:z", 1.0, dur * 0.36)
		PAWN:
			# 突刺：短促前倾突进，盾牌前顶
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(-10), dur * 0.20)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.02, 0.98, 1.02), dur * 0.20)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(5), dur * 0.32)
			pose.tween_property(_root_visual, "rotation:x", 0.0, dur * 0.30).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			var spear2 := _top_node.get_node_or_null("Spear") as MeshInstance3D
			if spear2 != null:
				pose.parallel().tween_property(spear2, "position:z", 0.06, dur * 0.22)
				pose.tween_property(spear2, "position:z", 0.0, dur * 0.38)
			var sh2 := _body_node.get_node_or_null("Shield") as MeshInstance3D
			if sh2 != null:
				pose.parallel().tween_property(sh2, "position:z", 0.04, dur * 0.18)
				pose.tween_property(sh2, "position:z", 0.0, dur * 0.40)

	return tw

## 按棋子返回移动抛物高度（差异化）
func _move_jump_height() -> float:
	match _piece_type:
		KING: return 0.20
		ADVISOR: return 0.16
		ELEPHANT: return 0.12
		HORSE: return 0.32
		CHARIOT: return 0.07
		CANNON: return 0.10
		PAWN: return 0.14
		_: return 0.16

## 击杀动作：原地向目标冲撞再返回，带类型差异化
## spec: play_capture(target) — 将帅剑气斩击 / 战车冲锋碾压 等七子差异化
func play_capture_attack(target_pos: Vector3, duration: float = 0.38) -> Tween:
	_stop_idle()
	_kill_move_tween()
	var start_pos: Vector3 = position
	var dir: Vector3 = target_pos - start_pos
	var dist: float = dir.length()
	if dist < 0.08:
		dir = Vector3(0, 0, 1)
	else:
		dir = dir / dist
	# 冲刺距离：按类型差异，车/马冲得远，炮短促
	var lunge: float = 0.42
	match _piece_type:
		HORSE: lunge = 0.52
		CHARIOT: lunge = 0.58
		CANNON: lunge = 0.28
		ELEPHANT: lunge = 0.34
		KING: lunge = 0.46
		PAWN: lunge = 0.30
		ADVISOR: lunge = 0.36
	if dist < lunge:
		lunge = dist * 0.78
	var mid_pos: Vector3 = start_pos + dir * lunge
	# 炮的攻击高度略高（炮弹出膛感）
	var extra_h: float = 0.06 if _piece_type == CANNON else 0.02

	_root_visual.position = Vector3.ZERO
	_root_visual.rotation = Vector3.ZERO
	_root_visual.scale = Vector3.ONE

	var dur: float = maxf(duration, 0.16)
	var out_dur: float = dur * 0.42
	var back_dur: float = dur * 0.58

	# 主位移往返（self.position）
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 去程：冲向目标，抛物微升
	tw.tween_method(func(p: float) -> void:
		var pos: Vector3 = start_pos.lerp(mid_pos, p)
		pos.y += sin(p * PI) * (0.14 + extra_h)
		position = pos
	, 0.0, 1.0, out_dur)
	tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# 回程：带回弹
	tw.tween_method(func(p: float) -> void:
		var pos: Vector3 = mid_pos.lerp(start_pos, p)
		# 回程高度略低
		pos.y += sin(p * PI) * 0.06
		position = pos
	, 0.0, 1.0, back_dur)
	_move_tween = tw

	# 姿态差异化
	var pose := create_tween()
	_pose_tween = pose

	match _piece_type:
		HORSE:
			# 奔跑跳跃 + 冲撞：扬蹄跃起，头槌冲撞
			pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(-24), out_dur * 0.85)
			pose.parallel().tween_property(_root_visual, "position:y", 0.10, out_dur * 0.7)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.04, 0.94, 1.04), out_dur * 0.5)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(12), back_dur * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pose.tween_property(_root_visual, "rotation:x", 0.0, back_dur * 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3.ONE, back_dur)
			var hhead3 := _top_node.get_node_or_null("HorseHead") as MeshInstance3D
			if hhead3 != null:
				pose.parallel().tween_property(hhead3, "rotation:x", deg_to_rad(-12), out_dur)
				pose.tween_property(hhead3, "rotation:x", 0.0, back_dur)
			pose.parallel().tween_callback(func() -> void:
				_do_impact_flash(0.12)
			)
		CHARIOT:
			# 直线冲锋 + 碾压：车体前倾，轮子狂转，碾过震动
			pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(13), out_dur * 0.9)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.05, 0.93, 1.05), out_dur * 0.6)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(-8), back_dur * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pose.tween_property(_root_visual, "rotation:x", 0.0, back_dur * 0.65).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			for wn in ["WheelLF", "WheelRF", "WheelLB", "WheelRB"]:
				var w2 := _base_node.get_node_or_null(wn) as MeshInstance3D
				if w2 != null:
					pose.parallel().tween_property(w2, "rotation:y", deg_to_rad(1080), dur).set_trans(Tween.TRANS_LINEAR)
			pose.parallel().tween_callback(func() -> void: _do_impact_flash(0.14))
		CANNON:
			# 后坐发射 + 爆炸：炮身后坐，炮管猛然后座再前喷，目标点爆炸缩放
			pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			pose.tween_property(_root_visual, "position:z", -0.12, out_dur * 0.45)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(0.94, 1.02, 0.94), out_dur * 0.45)
			var barrel3 := _body_node.get_node_or_null("Barrel") as MeshInstance3D
			if barrel3 != null:
				pose.parallel().tween_property(barrel3, "position:z", -0.14, out_dur * 0.45)
				pose.parallel().tween_property(barrel3, "scale:z", 0.78, out_dur * 0.40)
			pose.tween_property(_root_visual, "position:z", 0.05, out_dur * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if barrel3 != null:
				pose.parallel().tween_property(barrel3, "position:z", 0.0, dur * 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				pose.parallel().tween_property(barrel3, "scale:z", 1.0, dur * 0.55)
			pose.tween_property(_root_visual, "position:z", 0.0, back_dur).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3.ONE, back_dur)
			# 模拟炮口爆炸：顶珠/火光缩放
			pose.parallel().tween_callback(func() -> void: _spawn_muzzle_flash(mid_pos))
		ELEPHANT:
			# 沉重踏步 + 鼻扫：重踏蓄力，象鼻横扫
			pose.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			pose.tween_property(_root_visual, "position:y", -0.04, out_dur * 0.5)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.06, 0.88, 1.06), out_dur * 0.5)
			pose.tween_property(_root_visual, "position:y", 0.06, out_dur * 0.5)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(0.98, 1.06, 0.98), out_dur * 0.5)
			pose.tween_property(_root_visual, "position:y", 0.0, back_dur).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3.ONE, back_dur)
			pose.parallel().tween_property(_root_visual, "rotation:z", deg_to_rad(7), out_dur)
			pose.tween_property(_root_visual, "rotation:z", 0.0, back_dur)
			var trunk3 := _top_node.get_node_or_null("Trunk") as MeshInstance3D
			if trunk3 != null:
				pose.parallel().tween_property(trunk3, "rotation:z", deg_to_rad(-28), out_dur * 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				pose.tween_property(trunk3, "rotation:z", 0.0, back_dur * 0.85)
			pose.parallel().tween_callback(func() -> void: _do_impact_flash(0.13))
		ADVISOR:
			# 拂袖 + 笏击：拂袖上扬，笏板劈击
			pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pose.tween_property(_body_node, "rotation:z", deg_to_rad(-12), out_dur * 0.6)
			pose.parallel().tween_property(_root_visual, "position:y", 0.06, out_dur * 0.6)
			var tablet3 := _body_node.get_node_or_null("Tablet") as MeshInstance3D
			if tablet3 != null:
				pose.parallel().tween_property(tablet3, "rotation:x", deg_to_rad(42), out_dur * 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pose.tween_property(_body_node, "rotation:z", 0.0, back_dur * 0.7)
			pose.parallel().tween_property(_root_visual, "position:y", 0.0, back_dur)
			if tablet3 != null:
				pose.parallel().tween_property(tablet3, "rotation:x", deg_to_rad(8), back_dur * 0.8)
			pose.parallel().tween_callback(func() -> void: _do_impact_flash(0.10))
		KING:
			# 御驾突进 + 剑气：大范围横斩，残影鼓胀
			pose.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			pose.tween_property(_root_visual, "rotation:y", deg_to_rad(-28), out_dur * 0.65)
			pose.parallel().tween_property(_root_visual, "scale", Vector3(1.08, 0.92, 1.08), out_dur * 0.55)
			pose.tween_property(_root_visual, "rotation:y", deg_to_rad(36), back_dur * 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pose.tween_property(_root_visual, "rotation:y", 0.0, back_dur * 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			pose.parallel().tween_property(_root_visual, "scale", Vector3.ONE, back_dur)
			var jewel2 := _top_node.get_node_or_null("CrownJewel") as MeshInstance3D
			if jewel2 != null:
				pose.parallel().tween_property(jewel2, "rotation:y", deg_to_rad(180), dur * 0.7)
				pose.tween_property(jewel2, "rotation:y", 0.0, dur * 0.30)
			pose.parallel().tween_callback(func() -> void: _do_impact_flash(0.16))
		PAWN:
			# 突刺 + 盾击：矛尖突刺，盾牌前顶
			pose.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			pose.tween_property(_root_visual, "rotation:x", deg_to_rad(-14), out_dur * 0.75)
			pose.parallel().tween_property(_root_visual, "position:y", 0.04, out_dur * 0.6)
			var spear3 := _top_node.get_node_or_null("Spear") as MeshInstance3D
			var sh3 := _body_node.get_node_or_null("Shield") as MeshInstance3D
			if spear3 != null:
				pose.parallel().tween_property(spear3, "position:z", 0.12, out_dur * 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if sh3 != null:
				pose.parallel().tween_property(sh3, "position:z", 0.08, out_dur * 0.6)
				pose.parallel().tween_property(sh3, "rotation:y", deg_to_rad(-14), out_dur * 0.6)
			pose.tween_property(_root_visual, "rotation:x", 0.0, back_dur).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			pose.parallel().tween_property(_root_visual, "position:y", 0.0, back_dur)
			if spear3 != null:
				pose.parallel().tween_property(spear3, "position:z", 0.0, back_dur * 0.9)
			if sh3 != null:
				pose.parallel().tween_property(sh3, "position:z", 0.0, back_dur * 0.9)
				pose.parallel().tween_property(sh3, "rotation:y", 0.0, back_dur * 0.9)
			pose.parallel().tween_callback(func() -> void: _do_impact_flash(0.11))

	return tw

## 兼容封装：spec 要求的 play_capture(target, duration)
func play_capture(target = null, duration: float = 0.38) -> Tween:
	var target_pos: Vector3 = Vector3.ZERO
	if target is Vector3:
		target_pos = target
	elif target is Vector2i:
		target_pos = Vector3((target.x - 4) * 1.0, 0.22, (target.y - 4.5) * 1.0)
	elif target is Vector2:
		target_pos = Vector3(target.x, 0.22, target.y)
	elif target == null:
		target_pos = position + Vector3(0, 0, 1.0)
	return play_capture_attack(target_pos, duration)

## 击中闪光：短促缩放 + 材质闪白（模拟冲击）
func _do_impact_flash(intensity: float) -> void:
	# 轻微整体脉冲缩放
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_root_visual, "scale", Vector3(1.0 + intensity, 1.0 - intensity * 0.45, 1.0 + intensity), 0.07)
	t.tween_property(_root_visual, "scale", Vector3.ONE, 0.13).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## 炮口闪光：临时在炮口生成一个发光球，快速放大消失
func _spawn_muzzle_flash(_at_pos: Vector3) -> void:
	if _body_node == null or not is_instance_valid(_body_node):
		return
	var flash_mat := _make_mat(Color("#FFE8A0"), 0.0, 0.32, Color("#FFD54F"), 3.2)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flash_mesh := SphereMesh.new(); flash_mesh.radius = 0.09; flash_mesh.height = 0.18; flash_mesh.radial_segments = 10; flash_mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = flash_mesh
	mi.material_override = flash_mat
	mi.position = Vector3(0, 0.38, 0.42) # 相对于 _body_node 的炮口位置
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body_node.add_child(mi)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(2.4, 2.4, 2.4), 0.12)
	tw.parallel().tween_property(flash_mat, "albedo_color", Color(flash_mat.albedo_color.r, flash_mat.albedo_color.g, flash_mat.albedo_color.b, 0.0), 0.15)
	tw.tween_callback(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)

## 死亡动画：差异化倾倒/碎裂/淡出
func play_death(duration: float = 0.62) -> Tween:
	_stop_idle()
	_kill_move_tween()
	_kill_death_tweens()
	var dur: float = maxf(duration, 0.28)
	_prepare_fade()

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	match _piece_type:
		KING:
			# 王之陨落：缓缓倾倒，皇冠坠落，整体碎裂淡出
			tw.tween_property(_root_visual, "rotation:z", deg_to_rad(86), dur * 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_root_visual, "position:y", -0.48, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_root_visual, "scale", Vector3(0.72, 0.72, 0.72), dur * 0.9)
			# 皇冠珠额外抛起再坠
			var jewel3 := _top_node.get_node_or_null("CrownJewel") as MeshInstance3D
			if jewel3 != null:
				var jtw := _track_death_tween(create_tween())
				jtw.set_trans(Tween.TRANS_QUAD)
				jtw.tween_property(jewel3, "position:y", 0.55, dur * 0.28).set_ease(Tween.EASE_OUT)
				jtw.tween_property(jewel3, "position:y", -0.85, dur * 0.58).set_ease(Tween.EASE_IN)
				jtw.parallel().tween_property(jewel3, "rotation:z", deg_to_rad(200), dur * 0.86)
		ADVISOR:
			# 文官殉道：拂袖后倒，笏板脱手飞出
			tw.tween_property(_root_visual, "rotation:x", deg_to_rad(78), dur * 0.68).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_root_visual, "position:y", -0.38, dur)
			tw.parallel().tween_property(_root_visual, "scale", Vector3(0.78, 0.78, 0.78), dur)
			var tablet4 := _body_node.get_node_or_null("Tablet") as MeshInstance3D
			if tablet4 != null:
				var ttw := _track_death_tween(create_tween())
				ttw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				ttw.tween_property(tablet4, "position:z", 0.42, dur * 0.32)
				ttw.parallel().tween_property(tablet4, "rotation:x", deg_to_rad(70), dur * 0.42)
				ttw.tween_property(tablet4, "position:y", -0.65, dur * 0.55).set_ease(Tween.EASE_IN)
		ELEPHANT:
			# 巨兽倒塌：侧倒重压，地面震动 squash
			tw.tween_property(_root_visual, "rotation:z", deg_to_rad(84), dur * 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_root_visual, "position:y", -0.42, dur)
			tw.parallel().tween_property(_root_visual, "scale", Vector3(1.10, 0.62, 1.05), dur * 0.38)
			tw.tween_property(_root_visual, "scale", Vector3(0.70, 0.70, 0.70), dur * 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			# 象鼻无力垂落
			var trunk4 := _top_node.get_node_or_null("Trunk") as MeshInstance3D
			if trunk4 != null:
				var etw := _track_death_tween(create_tween())
				etw.tween_property(trunk4, "rotation:x", deg_to_rad(42), dur * 0.6)
		HORSE:
			# 烈马悲鸣：前蹄扬起后翻倒
			tw.tween_property(_root_visual, "rotation:x", deg_to_rad(-28), dur * 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(_root_visual, "position:y", 0.16, dur * 0.26)
			tw.tween_property(_root_visual, "rotation:z", deg_to_rad(92), dur * 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_root_visual, "position:y", -0.45, dur * 0.62)
			tw.parallel().tween_property(_root_visual, "scale", Vector3(0.74, 0.74, 0.74), dur)
			var hhead4 := _top_node.get_node_or_null("HorseHead") as MeshInstance3D
			if hhead4 != null:
				var htw := _track_death_tween(create_tween())
				htw.tween_property(hhead4, "rotation:x", deg_to_rad(-18), dur * 0.30)
		CHARIOT:
			# 战车解体：底盘、车厢、战旗三层分离飞散
			tw.tween_property(_root_visual, "rotation:z", deg_to_rad(14), dur * 0.32)
			tw.parallel().tween_property(_root_visual, "position:y", -0.18, dur * 0.32)
			# 解体分散在并行 Tween 中
			var dtw := _track_death_tween(create_tween())
			dtw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			dtw.tween_property(_body_node, "position:x", 0.42, dur * 0.48)
			dtw.parallel().tween_property(_body_node, "rotation:z", deg_to_rad(38), dur * 0.48)
			dtw.parallel().tween_property(_body_node, "position:y", -0.22, dur * 0.48)
			dtw.tween_property(_top_node, "position:x", -0.46, dur * 0.52)
			dtw.parallel().tween_property(_top_node, "rotation:z", deg_to_rad(-42), dur * 0.52)
			dtw.parallel().tween_property(_top_node, "position:y", -0.18, dur * 0.52)
			dtw.tween_property(_base_node, "position:y", -0.30, dur * 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			dtw.parallel().tween_property(_base_node, "scale", Vector3(0.72, 0.72, 0.72), dur * 0.48)
			# 轮子滚离
			for wn in ["WheelLF", "WheelRF", "WheelLB", "WheelRB"]:
				var w3 := _base_node.get_node_or_null(wn) as MeshInstance3D
				if w3 != null:
					var dir2: float = 1.0 if wn.begins_with("WheelR") else -1.0
					dtw.parallel().tween_property(w3, "position:x", dir2 * 0.55, dur * 0.55)
					dtw.parallel().tween_property(w3, "rotation:y", deg_to_rad(720 * dir2), dur * 0.55)
			tw.parallel().tween_property(_root_visual, "scale", Vector3(0.68, 0.68, 0.68), dur)
		CANNON:
			# 炸膛：炮管冲天飞起，炮架散开，黑烟感缩放
			tw.tween_property(_root_visual, "scale", Vector3(1.12, 1.12, 1.12), dur * 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_root_visual, "scale", Vector3(0.62, 0.62, 0.62), dur * 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_root_visual, "position:y", -0.42, dur)
			tw.parallel().tween_property(_root_visual, "rotation:z", deg_to_rad(18), dur * 0.55)
			var barrel4 := _body_node.get_node_or_null("Barrel") as MeshInstance3D
			if barrel4 != null:
				var btw := _track_death_tween(create_tween())
				btw.set_trans(Tween.TRANS_QUAD)
				btw.tween_property(barrel4, "position:y", 0.62, dur * 0.24).set_ease(Tween.EASE_OUT)
				btw.parallel().tween_property(barrel4, "rotation:x", deg_to_rad(62), dur * 0.34)
				btw.parallel().tween_property(barrel4, "scale", Vector3(0.86, 0.86, 0.86), dur * 0.24)
				btw.tween_property(barrel4, "position:y", -0.55, dur * 0.52).set_ease(Tween.EASE_IN)
				btw.parallel().tween_property(barrel4, "rotation:z", deg_to_rad(88), dur * 0.52)
			# 炮轮飞散
			for wn2 in ["WheelL", "WheelR"]:
				var w4 := _base_node.get_node_or_null(wn2) as MeshInstance3D
				if w4 != null:
					var dir3: float = 1.0 if wn2 == "WheelR" else -1.0
					var wtw := _track_death_tween(create_tween())
					wtw.tween_property(w4, "position:x", dir3 * 0.48, dur * 0.45)
					wtw.parallel().tween_property(w4, "rotation:y", deg_to_rad(540 * dir3), dur * 0.55)
		PAWN:
			# 步兵阵亡：直挺后倒，矛斜飞
			tw.tween_property(_root_visual, "rotation:x", deg_to_rad(88), dur * 0.60).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_root_visual, "position:y", -0.36, dur)
			tw.parallel().tween_property(_root_visual, "scale", Vector3(0.78, 0.78, 0.78), dur)
			var spear4 := _top_node.get_node_or_null("Spear") as MeshInstance3D
			var spear_head4 := _top_node.get_node_or_null("SpearHead") as MeshInstance3D
			if spear4 != null:
				var stw := _track_death_tween(create_tween())
				stw.tween_property(spear4, "position:y", 0.42, dur * 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				stw.tween_property(spear4, "position:y", -0.52, dur * 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				stw.parallel().tween_property(spear4, "rotation:z", deg_to_rad(68), dur * 0.62)
			if spear_head4 != null:
				var shtw := _track_death_tween(create_tween())
				shtw.tween_property(spear_head4, "position:y", 0.42, dur * 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				shtw.tween_property(spear_head4, "position:y", -0.52, dur * 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			var sh5 := _body_node.get_node_or_null("Shield") as MeshInstance3D
			if sh5 != null:
				var shield_tw := _track_death_tween(create_tween())
				shield_tw.tween_property(sh5, "rotation:y", deg_to_rad(42), dur * 0.38)
				shield_tw.parallel().tween_property(sh5, "position:x", -0.22, dur * 0.38)

	# 并行淡出所有材质到透明
	var mats := _collect_materials()
	for m in mats:
		# 已在 _prepare_fade 中切为 ALPHA，此处 tween alpha 到 0
		var target_col := Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b, 0.0)
		tw.parallel().tween_property(m, "albedo_color", target_col, dur * 0.88).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if m.emission_enabled:
			tw.parallel().tween_property(m, "emission", Color(0, 0, 0, 0), dur * 0.55)

	# 淡出结束隐藏节点（便于对象池回收）
	tw.tween_callback(func() -> void:
		visible = false
	)

	_move_tween = tw
	return tw

## 选中态：鎏金光环 + 轻微抬起发光
func set_selected(selected: bool) -> void:
	if _is_selected == selected:
		return
	_is_selected = selected
	if _select_ring == null or not is_instance_valid(_select_ring):
		return
	if _select_tween != null and _select_tween.is_valid():
		_select_tween.kill()
		_select_tween = null

	if selected:
		if _select_pulse_tween != null and _select_pulse_tween.is_valid():
			_select_pulse_tween.kill()
			_select_pulse_tween = null
		_select_ring.visible = true
		_select_ring.scale = Vector3.ONE
		# 抬起效果
		var tw := create_tween()
		_select_tween = tw
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_root_visual, "position:y", 0.06, 0.16)
		tw.parallel().tween_property(_root_visual, "scale", Vector3(1.06, 1.06, 1.06), 0.16)
		# 光环脉冲（循环）—— 独立句柄，不占用 _highlight_tween
		var pulse := create_tween()
		pulse.set_loops(0)
		pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(_select_ring, "scale", Vector3(1.10, 1.10, 1.10), 0.62)
		pulse.tween_property(_select_ring, "scale", Vector3.ONE, 0.62)
		_select_pulse_tween = pulse
	else:
		# 取消选中脉冲
		if _select_pulse_tween != null and _select_pulse_tween.is_valid():
			_select_pulse_tween.kill()
			_select_pulse_tween = null
		_select_ring.visible = false
		_select_ring.scale = Vector3.ONE
		var tw2 := create_tween()
		_select_tween = tw2
		tw2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_property(_root_visual, "position:y", 0.0, 0.14)
		tw2.parallel().tween_property(_root_visual, "scale", Vector3.ONE, 0.14)

## 高亮可落点：青玉/金薄环 + 轻微呼吸（与选中环互不干扰）
func set_highlight(highlight: bool) -> void:
	if _is_highlighted == highlight:
		return
	_is_highlighted = highlight
	if _highlight_ring == null or not is_instance_valid(_highlight_ring):
		return
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
		_highlight_tween = null
	if highlight:
		_highlight_ring.visible = true
		_highlight_ring.scale = Vector3.ONE
		var mat := _highlight_ring.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = 0.72
		var tw := create_tween()
		tw.set_loops(0)
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_highlight_ring, "scale", Vector3(1.14, 1.14, 1.14), 0.52)
		tw.tween_property(_highlight_ring, "scale", Vector3.ONE, 0.52)
		if mat != null:
			tw.parallel().tween_property(mat, "albedo_color:a", 0.32, 0.52)
			tw.tween_property(mat, "albedo_color:a", 0.72, 0.52)
		_highlight_tween = tw
	else:
		_highlight_ring.visible = false
		_highlight_ring.scale = Vector3.ONE


# ─────────────────────────────────────────────────────────────
# 生命周期
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	# 若外部在 add_child 前已调用 setup，则 _ready 不重复构建
	if _piece_type == 0:
		return
	if _root_visual == null:
		return
	# 确保待机在入树后播放
	if _idle_tween == null:
		play_idle()

func _exit_tree() -> void:
	_clear_piece()
