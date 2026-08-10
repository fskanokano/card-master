extends Node
## NetworkHub - transport abstraction: LAN (ENet) now, Online (stub) later.
## Game code talks to NetworkHub; swapping transport does not touch game logic.

enum Transport { OFFLINE, LAN, ONLINE }

var transport: Transport = Transport.OFFLINE
var peer: ENetMultiplayerPeer

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connection_failed

func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_connected.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_disconnected.emit(id))
	multiplayer.connection_failed.connect(func() -> void: connection_failed.emit())
	multiplayer.server_disconnected.connect(func() -> void: _on_server_disconnected())

func _on_server_disconnected() -> void:
	transport = Transport.OFFLINE
	peer = null
	multiplayer.multiplayer_peer = null

# -- LAN (ENet) --

func host_lan(port: int = 7777, max_players: int = 2) -> Error:
	leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, max_players)
	if err != OK:
		push_error("NetworkHub.host_lan failed: %s" % error_string(err))
		return err
	peer = p
	multiplayer.multiplayer_peer = peer
	transport = Transport.LAN
	return OK

func join_lan(ip: String, port: int = 7777) -> Error:
	leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, port)
	if err != OK:
		push_error("NetworkHub.join_lan failed: %s" % error_string(err))
		return err
	peer = p
	multiplayer.multiplayer_peer = peer
	transport = Transport.LAN
	return OK

# -- Online (stub - logs warning, returns ERR_UNAVAILABLE) --

func host_online(_config: Dictionary = {}) -> Error:
	push_warning("NetworkHub.host_online: Online not implemented yet.")
	return ERR_UNAVAILABLE

func join_online(_config: Dictionary = {}) -> Error:
	push_warning("NetworkHub.join_online: Online not implemented yet.")
	return ERR_UNAVAILABLE

# -- Common --

func leave() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	transport = Transport.OFFLINE

func is_host() -> bool:
	return multiplayer.is_server() and transport != Transport.OFFLINE

func is_connected_to_peer() -> bool:
	return transport != Transport.OFFLINE and peer != null

func get_unique_id() -> int:
	return multiplayer.get_unique_id()

## Placeholder for future reliable RPC broadcast.
func send_reliable(data: Dictionary) -> void:
	if transport == Transport.OFFLINE or peer == null:
		push_warning("NetworkHub.send_reliable: no active transport/peer, dropping data.")
		return
	# TODO: wire to MultiplayerAPI RPC once message routing is defined.
	_rpc_recv_reliable.rpc(data)

@rpc("any_peer", "call_local", "reliable")
func _rpc_recv_reliable(_data: Dictionary) -> void:
	pass
