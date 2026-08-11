extends Node
## AudioManager — 全局免费自制音效，零 external key，直接 res://assets/sfx 播放
## 用法：AudioManager.play_tap() / play_move(is_capture) / play_invalid() 等

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _enabled: bool = true
var _next_idx: int = 0

func _ready() -> void:
	# 5 路复用，避免抢占
	for i in range(5):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	# 预载 — 首次播放前已就绪，失败静默
	_preload("tap", "res://assets/sfx/tap.wav")
	_preload("select", "res://assets/sfx/select.wav")
	_preload("pickup", "res://assets/sfx/pickup.wav")
	_preload("drop", "res://assets/sfx/drop.wav")
	_preload("move", "res://assets/sfx/move.wav")
	_preload("capture", "res://assets/sfx/capture.wav")
	_preload("check", "res://assets/sfx/check.wav")
	_preload("invalid", "res://assets/sfx/invalid.wav")
	_preload("win", "res://assets/sfx/win.wav")
	_preload("lose", "res://assets/sfx/lose.wav")
	# 尊重系统静音：若用户在设置里关闭，可切 _enabled = false
	_enabled = true

func _preload(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path) as AudioStream
		if s != null:
			_streams[key] = s

func _play(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _enabled:
		return
	var stream: AudioStream = _streams.get(key, null) as AudioStream
	if stream == null:
		return
	var p: AudioStreamPlayer = _players[_next_idx % _players.size()]
	_next_idx += 1
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	# 轻微随机 pitch 防呆板
	if key in ["tap", "select", "pickup"]:
		p.pitch_scale = randf_range(0.96, 1.04)
	p.play()

func set_enabled(v: bool) -> void:
	_enabled = v

# ── 快捷 ──
func play_tap() -> void: _play("tap", -1.0)
func play_select() -> void: _play("select", -0.5)
func play_pickup() -> void: _play("pickup", -1.5)
func play_drop_ok() -> void: _play("drop", -0.5)
func play_move() -> void: _play("move", -0.8)
func play_capture() -> void: _play("capture", -0.6)
func play_check() -> void: _play("check", -0.4)
func play_invalid() -> void: _play("invalid", -1.0)
func play_win() -> void: _play("win", -1.0)
func play_lose() -> void: _play("lose", -1.0)

func play_move_result(is_capture: bool, is_check: bool) -> void:
	if is_check:
		play_check()
	elif is_capture:
		play_capture()
	else:
		play_move()

func play_bounce_back() -> void:
	play_invalid()
	if OS.has_feature("mobile") or DisplayServer.get_name() in ["Android", "iOS"]:
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(40)
