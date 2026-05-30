## LESSON 06: Lobby System
##
## Concepts:
##   - Player registry: server keeps authoritative list of players
##   - Syncing the full player list to late joiners
##   - Ready-up system: tracking which players are ready
##   - Starting the game: server decides when all ready
##   - Sending player metadata (name, color) from client to server
##   - Broadcasting state changes to all peers
##
## Pattern: server owns all game state. Clients push changes via RPC.
## Server validates, then broadcasts authoritative state to everyone.

extends Control

const PORT := 7005

# Player data stored on ALL peers (kept in sync via RPCs)
# Key = peer_id, Value = { name, color, ready }
var players: Dictionary = {}

func _ready() -> void:
	$VBox/ConnectRow/HostBtn.pressed.connect(_on_host_pressed)
	$VBox/ConnectRow/JoinBtn.pressed.connect(_on_join_pressed)
	$VBox/ActionRow/ReadyBtn.pressed.connect(_on_ready_pressed)
	$VBox/ActionRow/StartBtn.pressed.connect(_on_start_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	# Register server as a player
	_register_player_locally(1, "Host", Color.CORNFLOWER_BLUE)
	refresh_player_list()
	log_line("Lobby open. Waiting for players...")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	var my_name := "Player_%d" % my_id
	var my_color := Color.from_hsv(fmod(my_id * 0.37, 1.0), 0.7, 0.9)
	log_line("Connected! My ID=%d" % my_id)
	# Tell server about ourselves
	register_with_server.rpc_id(1, my_name, my_color)

func _on_peer_connected(id: int) -> void:
	log_line("Peer %d joined the lobby" % id)
	# If I'm the server, send the new peer the full current player list
	if multiplayer.is_server():
		for pid in players:
			var p: Dictionary = players[pid]
			send_player_to_peer.rpc_id(id, pid, p.name, p.color, p.ready)

func _on_peer_disconnected(id: int) -> void:
	log_line("Peer %d left" % id)
	if players.has(id):
		players.erase(id)
		player_left_broadcast.rpc(id)
	refresh_player_list()

func _on_server_disconnected() -> void:
	log_line("Server disconnected.")
	players.clear()
	multiplayer.multiplayer_peer = null
	refresh_player_list()

# ── Client → Server: register ──────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func register_with_server(p_name: String, p_color: Color) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_register_player_locally(id, p_name, p_color)
	# Broadcast new player to ALL peers (including sender)
	broadcast_new_player.rpc(id, p_name, p_color)
	refresh_player_list()

# ── Server → All: broadcast new player ─────────────────────────────────

@rpc("authority", "call_local", "reliable")
func broadcast_new_player(id: int, p_name: String, p_color: Color) -> void:
	_register_player_locally(id, p_name, p_color)
	refresh_player_list()

# ── Server → specific peer: catch up on existing players ───────────────

@rpc("authority", "call_remote", "reliable")
func send_player_to_peer(id: int, p_name: String, p_color: Color, p_ready: bool) -> void:
	_register_player_locally(id, p_name, p_color)
	players[id].ready = p_ready
	refresh_player_list()

# ── Server → All: player left ───────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func player_left_broadcast(id: int) -> void:
	players.erase(id)
	refresh_player_list()

# ── Client → Server: toggle ready ──────────────────────────────────────

func _on_ready_pressed() -> void:
	if not multiplayer.has_multiplayer_peer():
		log_line("Not connected")
		return
	if multiplayer.is_server():
		set_ready_on_server()  # server calls directly, no RPC to self
	else:
		set_ready_on_server.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func set_ready_on_server() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var id := sender if sender != 0 else multiplayer.get_unique_id()
	if not players.has(id):
		return
	players[id].ready = not players[id].ready
	broadcast_ready_state.rpc(id, players[id].ready)
	refresh_player_list()

@rpc("authority", "call_local", "reliable")
func broadcast_ready_state(id: int, is_ready: bool) -> void:
	if players.has(id):
		players[id].ready = is_ready
	refresh_player_list()

# ── Server: start game ──────────────────────────────────────────────────

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		log_line("Only server can start the game")
		return
	var all_ready := players.values().filter(func(p): return p.name != "Host").all(func(p): return p.ready)
	if not all_ready:
		log_line("Not all players are ready!")
		return
	if players.size() < 2:
		log_line("Need at least 2 players")
		return
	start_game.rpc()

@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	log_line(">>> GAME STARTING! <<<")
	log_line("(In a real project: get_tree().change_scene_to_file(\"res://game.tscn\") here)")

# ── Helpers ─────────────────────────────────────────────────────────────

func _register_player_locally(id: int, p_name: String, p_color: Color) -> void:
	if not players.has(id):
		players[id] = { "name": p_name, "color": p_color, "ready": false }

func refresh_player_list() -> void:
	var list := $VBox/PlayerList
	list.clear()
	for id in players:
		var p: Dictionary = players[id]
		var status := "[READY]" if p.ready else "[not ready]"
		var me := " ← YOU" if id == multiplayer.get_unique_id() else ""
		list.add_item("%s  id=%d  %s%s" % [p.name, id, status, me])

func log_line(text: String) -> void:
	$VBox/Log.append_text(text + "\n")
