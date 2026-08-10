extends Node
## RoomManager — LAN room lifecycle. Host creates a room with a 6-char code;
## clients discover via LanDiscovery or enter code manually.
## Room code is derived deterministically so discovery + manual join agree.

signal room_created(code: String, port: int)
signal room_joined(code: String)
signal room_left
signal room_error(msg: String)
signal room_peer_joined(peer_id: int)
signal room_peer_left(peer_id: int)

const BASE_PORT := 7777

var current_code: String = ""
var current_port: int = BASE_PORT
var is_host: bool = false

# Advertise host_name in discovery beacon
var host_name: String = "Player"

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	NetworkHub.peer_connected.connect(func(id: int) -> void: room_peer_joined.emit(id))
	NetworkHub.peer_disconnected.connect(func(id: int) -> void: room_peer_left.emit(id))
	NetworkHub.connection_failed.connect(func() -> void: _on_connection_failed())

func generate_code() -> String:
	const ALPH := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" # no I/O/0/1
	var s: String = ""
	for _i in range(6):
		s += ALPH[_rng.randi_range(0, ALPH.length() - 1)]
	return s

## Host: create room, start ENet server + discovery broadcast.
func create_room(game_id: String = "xiangqi", preferred_code: String = "") -> String:
	leave_room()
	var code: String = preferred_code.strip_edges().to_upper() if preferred_code != "" else generate_code()
	# Try BASE_PORT then next 10 ports if occupied
	var port: int = BASE_PORT
	var last_err: Error = ERR_CANT_CREATE
	for attempt in range(10):
		var err: Error = NetworkHub.host_lan(port, 2)
		if err == OK:
			last_err = OK
			break
		port += 1
		last_err = err
	if last_err != OK:
		room_error.emit("Failed to host room: %s" % error_string(last_err))
		return ""
	current_code = code
	current_port = port
	is_host = true
	AppState.set_mode(AppState.Mode.LAN_HOST)
	host_name = AppState.player_name if AppState.player_name != "" else "Host"
	LanDiscovery.start_broadcasting(current_code, game_id, current_port, host_name)
	room_created.emit(current_code, current_port)
	return current_code

## Client: join by room code (via discovery) or direct IP:port fallback.
func join_room_by_code(code: String) -> Error:
	var needle: String = code.strip_edges().to_upper()
	if needle == "":
		room_error.emit("Please enter a room code.")
		return ERR_INVALID_PARAMETER
	var info: Dictionary = LanDiscovery.find_room_by_code(needle)
	if not info.is_empty():
		return join_room_at(info["ip"], int(info["port"]), needle)
	# Not discovered yet — try interpreting code as IP or room on default port
	# Also allow "IP:PORT" syntax
	if needle.contains(":"):
		var parts: PackedStringArray = needle.split(":")
		return join_room_at(parts[0], int(parts[1]), needle)
	# Try local subnet scan hint: no direct IP, so report not found
	room_error.emit("Room %s not found. Make sure host and client are on the same Wi-Fi." % needle)
	return ERR_DOES_NOT_EXIST

func join_room_at(ip: String, port: int, code_hint: String = "") -> Error:
	leave_room(false)
	var err: Error = NetworkHub.join_lan(ip, port)
	if err != OK:
		room_error.emit("Failed to join %s:%d — %s" % [ip, port, error_string(err)])
		return err
	current_code = code_hint if code_hint != "" else "%s:%d" % [ip, port]
	current_port = port
	is_host = false
	AppState.set_mode(AppState.Mode.LAN_CLIENT)
	LanDiscovery.start_listening()
	room_joined.emit(current_code)
	return OK

## Direct IP join without room code (back-compat with old Lobby).
func join_direct(ip: String, port: int = BASE_PORT) -> Error:
	return join_room_at(ip, port, "")

func leave_room(stop_discovery: bool = true) -> void:
	if current_code != "" or NetworkHub.transport != NetworkHub.Transport.OFFLINE:
		NetworkHub.leave()
		if stop_discovery:
			LanDiscovery.stop()
		current_code = ""
		is_host = false
		room_left.emit()

func _on_connection_failed() -> void:
	room_error.emit("Connection failed.")
	LanDiscovery.stop()
