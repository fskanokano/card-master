extends Node
## LanDiscovery — UDP broadcast discovery for LAN peers and rooms.
## Hosts broadcast their room; clients listen and build a live list.
## Pure discovery channel — does not carry game traffic (ENet does).

signal peer_found(info: Dictionary)   # {ip, port, room_code, host_name, game_id}
signal peer_lost(ip: String)
signal rooms_updated(rooms: Array)    # Array[Dictionary]

const BROADCAST_PORT := 7778
const BROADCAST_INTERVAL := 1.0       # seconds
const PEER_TIMEOUT := 4.0             # seconds without beacon => remove

var _udp: PacketPeerUDP = null
var _broadcasting: bool = false
var _listening: bool = false
var _broadcast_info: Dictionary = {}  # what we advertise
var _peers: Dictionary = {}           # ip -> {info, last_seen: float}
var _timer: float = 0.0

func _ready() -> void:
	set_process(false)

## Start advertising this device as a room host.
func start_broadcasting(room_code: String, game_id: String, enet_port: int, host_name: String) -> void:
	_broadcast_info = {
		"room_code": room_code,
		"game_id": game_id,
		"port": enet_port,
		"host_name": host_name,
	}
	if _udp == null:
		_udp = PacketPeerUDP.new()
	_ensure_bound()
	_broadcasting = true
	_listening = true
	_timer = 0.0
	set_process(true)
	_broadcast_once()

## Start listening for peers without advertising (client mode).
func start_listening() -> void:
	if _udp == null:
		_udp = PacketPeerUDP.new()
	_ensure_bound()
	_listening = true
	set_process(true)

func stop() -> void:
	_broadcasting = false
	_listening = false
	_peers.clear()
	if _udp != null:
		_udp.close()
		_udp = null
	set_process(false)
	rooms_updated.emit([])

func get_rooms() -> Array:
	var out: Array = []
	for ip in _peers.keys():
		out.append(_peers[ip]["info"])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("room_code", "") < b.get("room_code", ""))
	return out

func find_room_by_code(code: String) -> Dictionary:
	var needle: String = code.strip_edges().to_upper()
	for ip in _peers.keys():
		var info: Dictionary = _peers[ip]["info"]
		if info.get("room_code", "").to_upper() == needle:
			return info
	return {}

# -- internal --

func _ensure_bound() -> void:
	if _udp.is_bound():
		return
	# Bind to broadcast port on all interfaces; enable broadcast.
	var err: int = _udp.bind(BROADCAST_PORT)
	if err != OK:
		# Fallback: ephemeral port if 7778 occupied
		_udp.bind(0)
	_udp.set_broadcast_enabled(true)
	_udp.set_dest_address("255.255.255.255", BROADCAST_PORT)

func _broadcast_once() -> void:
	if not _broadcasting or _udp == null:
		return
	var payload: Dictionary = _broadcast_info.duplicate()
	payload["v"] = 1
	var bytes: PackedByteArray = JSON.stringify(payload).to_utf8_buffer()
	_udp.set_dest_address("255.255.255.255", BROADCAST_PORT)
	_udp.put_packet(bytes)
	# Also try subnet broadcast if we can infer it (best-effort)
	for addr in IP.get_local_addresses():
		if addr.contains(".") and not addr.begins_with("127."):
			var parts: PackedStringArray = addr.split(".")
			if parts.size() == 4:
				var bcast: String = "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
				_udp.set_dest_address(bcast, BROADCAST_PORT)
				_udp.put_packet(bytes)

func _process(delta: float) -> void:
	_timer += delta
	if _broadcasting and _timer >= BROADCAST_INTERVAL:
		_timer = 0.0
		_broadcast_once()
	# Drain inbound packets
	if _udp != null and _udp.is_bound():
		while _udp.get_available_packet_count() > 0:
			var bytes: PackedByteArray = _udp.get_packet()
			var ip: String = _udp.get_packet_ip()
			var text: String = bytes.get_string_from_utf8()
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				_on_beacon(ip, parsed)
	# Expire stale peers
	var now: float = Time.get_ticks_msec() / 1000.0
	var changed: bool = false
	for ip in _peers.keys():
		if now - float(_peers[ip]["last_seen"]) > PEER_TIMEOUT:
			_peers.erase(ip)
			peer_lost.emit(ip)
			changed = true
	if changed:
		rooms_updated.emit(get_rooms())

func _on_beacon(ip: String, data: Dictionary) -> void:
	if not data.has("room_code") or not data.has("port"):
		return
	# Ignore our own beacon (same room_code we broadcast)
	if _broadcasting and data.get("room_code", "") == _broadcast_info.get("room_code", ""):
		return
	# Ignore loopback from self when testing on one machine — dedup by ip+code
	# but still surface it so single-device testing works
	var info: Dictionary = {
		"ip": ip,
		"port": int(data.get("port", 7777)),
		"room_code": str(data.get("room_code", "")),
		"host_name": str(data.get("host_name", "Player")),
		"game_id": str(data.get("game_id", "xiangqi")),
	}
	var is_new: bool = not _peers.has(ip) or _peers[ip]["info"].get("room_code", "") != info["room_code"]
	_peers[ip] = {"info": info, "last_seen": Time.get_ticks_msec() / 1000.0}
	if is_new:
		peer_found.emit(info)
		rooms_updated.emit(get_rooms())
