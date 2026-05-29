## LESSON 07: Server Authority & Input Validation
##
## Concepts:
##   - Why client-authority fails: clients can send any position (cheating)
##   - Server-authority pattern: clients send INPUT, server moves, server syncs position
##   - Server validates: speed limit, boundary checks, anti-teleport
##   - Client-side prediction: move locally immediately, reconcile if server disagrees
##   - The trust hierarchy: server data always wins
##
## This lesson shows TWO boxes side-by-side:
##   LEFT  = Client-authority (lesson 05 pattern) — can be cheated
##   RIGHT = Server-authority (this pattern) — server validates
##
## In a real game: RIGHT is what you want for competitive games.

extends Node2D

const PORT := 7006
const SPEED := 150.0
const MAX_SPEED := 200.0  # Server rejects faster moves

# Server tracks authoritative positions
var _server_positions: Dictionary = {}  # peer_id → Vector2

func _ready() -> void:
	$UI/VBox/HostBtn.pressed.connect(_on_host_pressed)
	$UI/VBox/JoinBtn.pressed.connect(_on_join_pressed)
	$UI/VBox/DisconnectBtn.pressed.connect(_on_disconnect_pressed)
	$UI/VBox/CheatBtn.pressed.connect(_on_cheat_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): log_line("Connected. ID=%d" % multiplayer.get_unique_id()))

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	_server_positions[1] = $ServerBox.position
	log_line("Server. Arrow = move. Cheat button = try teleport (server will reject).")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_server_positions[id] = Vector2(400, 250)
		log_line("Player %d joined" % id)

func _on_peer_disconnected(id: int) -> void:
	_server_positions.erase(id)

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move := dir * SPEED * delta

	# ── CLIENT-AUTHORITY (LEFT BOX): client moves directly ──────────────
	# No validation. A hacked client can set position to anything.
	if not multiplayer.is_server():
		$ClientBox.position += move
		$ClientBox.position = $ClientBox.position.clamp(Vector2(0, 0), Vector2(350, 490))

	# ── SERVER-AUTHORITY (RIGHT BOX): client sends INPUT to server ───────
	if move != Vector2.ZERO:
		# Client sends its desired movement delta to the server
		send_input_to_server.rpc_id(1, move)

		# Client-side PREDICTION: move locally while waiting for server confirmation
		# If server disagrees, it will snap us back via update_server_box
		$ServerBox.position += move
		$ServerBox.position = $ServerBox.position.clamp(Vector2(0, 0), Vector2(350, 490))

func _on_cheat_pressed() -> void:
	if not multiplayer.has_multiplayer_peer():
		log_line("Not connected")
		return
	log_line("CHEAT: sending teleport to (999, 999) — server should reject this")
	# Fake a huge move — server will clamp/reject it
	send_input_to_server.rpc_id(1, Vector2(999, 999))

# ── Client → Server: send input ──────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func send_input_to_server(move_delta: Vector2) -> void:
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()
	if not _server_positions.has(id):
		_server_positions[id] = Vector2(400, 250)

	# SERVER VALIDATION: reject moves that are too fast (cheat detection)
	var max_move := MAX_SPEED / Engine.physics_ticks_per_second
	if move_delta.length() > max_move * 2:  # allow 2x for network jitter
		log_line("REJECTED cheat move from peer %d (delta=%s)" % [id, move_delta])
		# Force-correct the client by sending authoritative position
		correct_client_position.rpc_id(id, _server_positions[id])
		return

	# Apply validated move
	_server_positions[id] += move_delta
	_server_positions[id] = _server_positions[id].clamp(Vector2(0, 0), Vector2(350, 490))

	# Broadcast authoritative position to ALL peers (including mover)
	update_server_box.rpc(_server_positions[id], id)

# ── Server → All: authoritative position update ───────────────────────────

@rpc("authority", "call_local", "reliable")
func update_server_box(pos: Vector2, owner_id: int) -> void:
	# In a real game: find the correct player node by owner_id and set its position
	# Here we just move the demo box for the local peer
	if owner_id == multiplayer.get_unique_id() or multiplayer.is_server():
		$ServerBox.position = pos

@rpc("authority", "call_remote", "reliable")
func correct_client_position(pos: Vector2) -> void:
	log_line("Server corrected our position to %s" % pos)
	$ServerBox.position = pos

func log_line(text: String) -> void:
	$UI/VBox/Log.append_text(text + "\n")
