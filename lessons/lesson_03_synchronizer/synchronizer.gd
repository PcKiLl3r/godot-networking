## LESSON 03: MultiplayerSynchronizer
##
## Concepts:
##   - MultiplayerSynchronizer node: auto-replicates property values to peers
##   - You DON'T write RPCs for properties — just add them to the synchronizer
##   - set_multiplayer_authority(id): determines which peer is the "writer"
##     Only the authority sends updates; others receive them (read-only)
##   - Replication mode: ALWAYS (every tick) vs ON_CHANGE (only when changed)
##   - sync_interval: how often it sends (seconds). 0 = every physics frame
##   - The "watched" box below moves on the authority; all others follow
##
## Scene structure needed:
##   Control (this script)
##   └── VBox
##       ├── ... UI ...
##       └── Arena (SubViewportContainer or just Control)
##           └── Box (ColorRect) ← has MultiplayerSynchronizer child
##               └── Sync (MultiplayerSynchronizer)  ← watches Box.position
##
## Try it:
##   1. Host, then join
##   2. Server moves box with arrow keys — client sees it move automatically
##   3. Change authority to client ID — now client moves it

extends Control

const PORT := 7002

# Track box velocity for smooth movement
var _box_velocity := Vector2.ZERO

func _ready() -> void:
	$VBox/Buttons/HostBtn.pressed.connect(_on_host_pressed)
	$VBox/Buttons/JoinBtn.pressed.connect(_on_join_pressed)
	$VBox/Buttons/DisconnectBtn.pressed.connect(_on_disconnect_pressed)
	$VBox/TransferBtn.pressed.connect(_on_transfer_authority)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(func(): log_line("Connected. ID=%d" % multiplayer.get_unique_id()))

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	# Server (ID=1) is authority by default for all nodes
	log_line("Server started. I am authority of Box (ID=1)")
	log_line("Use Arrow Keys to move the box")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer = null
	log_line("Offline")

func _on_peer_connected(id: int) -> void:
	log_line("Peer %d connected" % id)

func _on_transfer_authority() -> void:
	# Only the SERVER can reassign authority
	if not multiplayer.is_server():
		log_line("Only server can transfer authority")
		return
	# Find a connected client to give authority to
	var peers := multiplayer.get_peers()
	if peers.is_empty():
		log_line("No clients connected")
		return
	var new_authority := peers[0]
	$Arena/Box.set_multiplayer_authority(new_authority)
	# Tell ALL peers who the new authority is, so they set it too
	sync_authority.rpc(new_authority)
	log_line("Authority transferred to peer %d" % new_authority)

@rpc("authority", "call_local", "reliable")
func sync_authority(new_owner_id: int) -> void:
	$Arena/Box.set_multiplayer_authority(new_owner_id)
	var mine := new_owner_id == multiplayer.get_unique_id()
	log_line("Authority is now peer %d  (mine=%s)" % [new_owner_id, mine])

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	# Only authority moves the box; others just receive via MultiplayerSynchronizer
	if not $Arena/Box.is_multiplayer_authority():
		return

	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"):  dir.x -= 1
	if Input.is_action_pressed("ui_down"):  dir.y += 1
	if Input.is_action_pressed("ui_up"):    dir.y -= 1

	$Arena/Box.position += dir * 200.0 * delta
	# Clamp within arena
	var arena_size: Vector2 = $Arena.size
	$Arena/Box.position = $Arena/Box.position.clamp(Vector2.ZERO, arena_size - Vector2(40, 40))

func log_line(text: String) -> void:
	$VBox/Log.append_text(text + "\n")
