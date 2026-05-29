## LESSON 04: MultiplayerSpawner
##
## Concepts:
##   - MultiplayerSpawner: when server instantiates a scene inside the spawn path,
##     ALL connected peers automatically get that node instantiated too
##   - Despawn: when server removes (queue_free) a node, all peers remove it too
##   - spawn_function: optional callback to customize the spawned node before it appears
##   - set_multiplayer_authority on spawned node: gives each player control of their own avatar
##   - spawned_custom: emit custom data from server to clients during spawn
##
## How it works:
##   Server calls $Arena/Spawner.spawn(data)
##   → Spawner instantiates the registered scene
##   → Replicates the node to all peers automatically
##   → Calls spawn_function on each peer to apply the data
##
## Try it:
##   1. Host in A, join in B
##   2. Each peer auto-spawns when they connect
##   3. Move your avatar with arrow keys — other player sees you move
##   4. Disconnect — your avatar disappears on all peers

extends Control

const PORT := 7003

# Colors per player slot
const PLAYER_COLORS := [
	Color(0.2, 0.6, 1.0),  # blue
	Color(1.0, 0.4, 0.2),  # orange
	Color(0.2, 0.9, 0.4),  # green
	Color(0.9, 0.2, 0.8),  # magenta
]

# Map peer_id → spawned node (server only)
var _player_nodes: Dictionary = {}

func _ready() -> void:
	$VBox/Buttons/HostBtn.pressed.connect(_on_host_pressed)
	$VBox/Buttons/JoinBtn.pressed.connect(_on_join_pressed)
	$VBox/Buttons/DisconnectBtn.pressed.connect(_on_disconnect_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	# Tell the spawner which scene to instantiate, and what function sets it up
	$Arena/Spawner.spawn_function = _spawn_player

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	log_line("Server started.")
	# Spawn the host's own avatar
	_spawn_player_for_peer(1)

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_connected_to_server() -> void:
	log_line("Connected. My ID=%d — telling server to spawn me" % multiplayer.get_unique_id())
	# Client tells server: "please spawn me"
	request_spawn.rpc_id(1)

func _on_peer_connected(id: int) -> void:
	log_line("Peer %d joined" % id)

func _on_peer_disconnected(id: int) -> void:
	log_line("Peer %d left" % id)
	# Server removes the disconnected player's avatar
	if multiplayer.is_server() and _player_nodes.has(id):
		_player_nodes[id].queue_free()
		_player_nodes.erase(id)

# Client asks server to spawn them
@rpc("any_peer", "call_remote", "reliable")
func request_spawn() -> void:
	var requester_id := multiplayer.get_remote_sender_id()
	log_line("Server: spawning player for peer %d" % requester_id)
	_spawn_player_for_peer(requester_id)

func _spawn_player_for_peer(peer_id: int) -> void:
	# Pack data to pass to spawn_function on all peers
	var idx := _player_nodes.size()
	var data := {
		"peer_id": peer_id,
		"color": PLAYER_COLORS[idx % PLAYER_COLORS.size()],
		"name": "P%d" % peer_id,
		"position": Vector2(50 + idx * 80, 130),
	}
	# spawn() triggers _spawn_player on ALL peers + server
	var node: ColorRect = $Arena/Spawner.spawn(data)
	_player_nodes[peer_id] = node

# spawn_function is called on EVERY peer (server + all clients) when a node spawns.
# It receives the data passed to Spawner.spawn() and must return a Node.
func _spawn_player(data: Dictionary) -> Node:
	var scene := preload("res://lessons/lesson_04_spawner/player_avatar.tscn")
	var avatar: ColorRect = scene.instantiate()

	avatar.name = "Player_%d" % data["peer_id"]
	avatar.player_name = data["name"]
	avatar.player_color = data["color"]
	avatar.position = data["position"]

	# Give authority over this avatar to its owner peer
	avatar.set_multiplayer_authority(data["peer_id"])

	return avatar

func log_line(text: String) -> void:
	$VBox/Log.append_text(text + "\n")
