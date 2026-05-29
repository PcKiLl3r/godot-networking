## LESSON 05: Player Movement — main scene controller
##
## Pattern used here (client-authority):
##   - Each client is authority of its own player node
##   - Client reads input directly, moves locally
##   - MultiplayerSynchronizer broadcasts position to all peers
##   - Server (and other clients) just receive the position
##
## This is fine for cooperative games or when you trust clients.
## For competitive/cheating-resistant: see Lesson 07 (server authority).

extends Node2D

const PORT := 7004
const PLAYER_COLORS := [Color.CORNFLOWER_BLUE, Color.TOMATO, Color.MEDIUM_SPRING_GREEN, Color.ORCHID]

var _players: Dictionary = {}  # peer_id → Player node

func _ready() -> void:
	$UI/VBox/Buttons/HostBtn.pressed.connect(_on_host_pressed)
	$UI/VBox/Buttons/JoinBtn.pressed.connect(_on_join_pressed)
	$UI/VBox/Buttons/DisconnectBtn.pressed.connect(_on_disconnect_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	$Spawner.spawn_function = _do_spawn

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	_spawn_player(1)
	log_line("Hosting. Arrow keys = move your player.")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_connected_to_server() -> void:
	log_line("Connected. ID=%d" % multiplayer.get_unique_id())
	request_spawn.rpc_id(1)

func _on_peer_connected(id: int) -> void:
	log_line("Peer %d connected" % id)

func _on_peer_disconnected(id: int) -> void:
	log_line("Peer %d left" % id)
	if _players.has(id):
		_players[id].queue_free()
		_players.erase(id)

func _on_server_disconnected() -> void:
	log_line("Server disconnected.")
	for p in _players.values():
		p.queue_free()
	_players.clear()
	multiplayer.multiplayer_peer = null

@rpc("any_peer", "call_remote", "reliable")
func request_spawn() -> void:
	_spawn_player(multiplayer.get_remote_sender_id())

func _spawn_player(peer_id: int) -> void:
	var idx := _players.size()
	var data := {
		"peer_id": peer_id,
		"color": PLAYER_COLORS[idx % PLAYER_COLORS.size()],
		"position": Vector2(100 + idx * 100, 250),
	}
	$Spawner.spawn(data)

func _do_spawn(data: Dictionary) -> Node:
	var scene := preload("res://lessons/lesson_05_player_movement/player.tscn")
	var player = scene.instantiate()
	player.name = "Player_%d" % data["peer_id"]
	player.player_id = data["peer_id"]
	player.player_color = data["color"]
	player.position = data["position"]
	player.set_multiplayer_authority(data["peer_id"])
	_players[data["peer_id"]] = player
	return player

func log_line(text: String) -> void:
	$UI/VBox/Log.append_text(text + "\n")
