## LESSON 07: Server Authority & Input Validation

extends Node2D

const PORT := 7006
const SPEED := 150.0
const MAX_SPEED := 200.0

var _server_positions: Dictionary = {}  # peer_id → Vector2 (server only)
var _dbg_last_send := ""
var _dbg_last_recv := ""

func _ready() -> void:
	$UI/VBox/Row/HostBtn.pressed.connect(_on_host_pressed)
	$UI/VBox/Row/JoinBtn.pressed.connect(_on_join_pressed)
	$UI/VBox/Row/DisconnectBtn.pressed.connect(_on_disconnect_pressed)
	$UI/VBox/Row/CheatBtn.pressed.connect(_on_cheat_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): log_line("Connected. ID=%d" % multiplayer.get_unique_id()))

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	_server_positions[1] = $ServerBox.position
	log_line("Server started. Move with arrow keys.")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_server_positions[id] = $ServerBox.position
		log_line("Peer %d joined" % id)

func _on_peer_disconnected(id: int) -> void:
	_server_positions.erase(id)

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move := dir * SPEED * delta

	# ── LEFT BOX: client-authority ──────────────────────────────────────
	# Every peer moves their own left box directly — no server involved.
	# Bug in real games: each client can teleport their box to any position.
	$ClientBox.position += move
	$ClientBox.position = $ClientBox.position.clamp(Vector2(0, 0), Vector2(340, 460))

	# ── RIGHT BOX: server-authority ─────────────────────────────────────
	if multiplayer.is_server():
		# SERVER moves right box directly — it is the authority, no RPC needed.
		# Then broadcasts authoritative position to all clients.
		if move != Vector2.ZERO:
			var my_id := multiplayer.get_unique_id()  # = 1
			_server_positions[my_id] = (_server_positions.get(my_id, $ServerBox.position) + move).clamp(Vector2(0,0), Vector2(340,460))
			update_server_box.rpc(_server_positions[my_id])
			_dbg_last_send = "BROADCAST pos=%s" % _server_positions[my_id]
	else:
		# CLIENT sends input delta to server, does local prediction.
		if move != Vector2.ZERO:
			_dbg_last_send = "SEND delta=%s to server" % move
			send_input_to_server.rpc_id(1, move)
			# Prediction: move immediately, server will correct if wrong
			$ServerBox.position = ($ServerBox.position + move).clamp(Vector2(0,0), Vector2(340,460))

	_update_debug()

func _on_cheat_pressed() -> void:
	if not multiplayer.has_multiplayer_peer():
		log_line("Not connected")
		return
	var cheat_delta := Vector2(999, 999)
	log_line("CHEAT ATTEMPT: sending delta=%s" % cheat_delta)
	_dbg_last_send = "CHEAT delta=%s" % cheat_delta
	send_input_to_server.rpc_id(1, cheat_delta)
	$ServerBox.position = ($ServerBox.position + cheat_delta).clamp(Vector2(0,0), Vector2(340,460))

# ── Client → Server ───────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func send_input_to_server(move_delta: Vector2) -> void:
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()
	_dbg_last_recv = "RECV from peer %d delta=%s" % [id, move_delta]

	if not _server_positions.has(id):
		_server_positions[id] = $ServerBox.position

	# Validate: reject suspiciously large deltas
	var max_allowed := (MAX_SPEED / Engine.physics_ticks_per_second) * 3.0
	if move_delta.length() > max_allowed:
		log_line("[SERVER] REJECTED from peer %d — delta %.1f > max %.1f" % [id, move_delta.length(), max_allowed])
		correct_client_position.rpc_id(id, _server_positions[id])
		return

	_server_positions[id] = (_server_positions[id] + move_delta).clamp(Vector2(0,0), Vector2(340,460))
	log_line("[SERVER] accepted from peer %d → pos=%s" % [id, _server_positions[id]])
	update_server_box.rpc(_server_positions[id])

# ── Server → All: authoritative position ─────────────────────────────────

@rpc("authority", "call_local", "reliable")
func update_server_box(pos: Vector2) -> void:
	$ServerBox.position = pos
	_dbg_last_recv = "RECV server pos=%s" % pos

# ── Server → Client: correction ──────────────────────────────────────────

@rpc("authority", "call_remote", "reliable")
func correct_client_position(pos: Vector2) -> void:
	log_line("[CLIENT] Server correction → snap to %s" % pos)
	$ServerBox.position = pos
	_dbg_last_recv = "CORRECTION snap to %s" % pos

# ── Debug HUD ─────────────────────────────────────────────────────────────

func _update_debug() -> void:
	if not has_node("UI/VBox/Debug"):
		return
	var role := "SERVER (id=1)" if multiplayer.is_server() else "CLIENT (id=%d)" % multiplayer.get_unique_id()
	var connected := multiplayer.has_multiplayer_peer()
	$UI/VBox/Debug.text = (
		"Role: %s  |  Connected: %s\n" % [role, connected] +
		"ClientBox (LEFT):  pos=%s  [moves locally, NO sync]\n" % [str($ClientBox.position.round())] +
		"ServerBox (RIGHT): pos=%s  [server validates + broadcasts]\n" % [str($ServerBox.position.round())] +
		"Last SENT:  %s\n" % _dbg_last_send +
		"Last RECV:  %s" % _dbg_last_recv
	)

func log_line(text: String) -> void:
	$UI/VBox/Log.append_text(text + "\n")
