## LESSON 10: Mini-Game — Everything Together
##
## This lesson combines ALL previous concepts into one working mini-game:
##
##   ✓ ENetMultiplayerPeer (L01)          — connect/disconnect
##   ✓ @rpc with all modes (L02)          — game events
##   ✓ MultiplayerSynchronizer (L03,L09)  — position + health sync + interpolation
##   ✓ MultiplayerSpawner (L04)           — spawn/despawn players
##   ✓ Input authority pattern (L05)      — each player owns their movement
##   ✓ Lobby/ready system (L06)           — wait for players, then start
##   ✓ Server authority (L07)             — server validates hits
##   ✓ Scene switching (L08)              — lobby → game → lobby
##
## GAME RULES:
##   - Collect coins (yellow squares) to score points
##   - Coins are server-spawned, server-authoritative (clients can't fake a pickup)
##   - First to 5 points wins
##   - Health system: touching other players costs HP
##
## ARCHITECTURE PATTERN USED:
##   GameState enum (LOBBY / PLAYING / GAME_OVER) drives UI visibility
##   Server owns all game state, broadcasts changes via RPC
##   Clients are presentational only — input + display

extends Node2D

const PORT := 7009
const MAX_PLAYERS := 4
const COINS_TO_WIN := 5
const COIN_COUNT := 6

enum State { LOBBY, PLAYING, GAME_OVER }

var _state: State = State.LOBBY
var _players: Dictionary = {}     # peer_id → GamePlayer node
var _scores: Dictionary = {}      # peer_id → int  (server authoritative)
var _coins: Array[Node2D] = []    # coin nodes (server spawns, all see via Spawner)
var _player_colors := [
	Color.CORNFLOWER_BLUE, Color.TOMATO, Color.MEDIUM_SPRING_GREEN, Color.ORCHID
]

func _ready() -> void:
	_connect_ui()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	$Arena/PlayerSpawner.spawn_function = _spawn_player_node
	$Arena/CoinSpawner.spawn_function = _spawn_coin_node
	_show_lobby()

func _connect_ui() -> void:
	$UI/Lobby/Row/HostBtn.pressed.connect(_on_host_pressed)
	$UI/Lobby/Row/JoinBtn.pressed.connect(_on_join_pressed)
	$UI/Lobby/StartBtn.pressed.connect(_on_start_pressed)
	$UI/GameOver/PlayAgainBtn.pressed.connect(_on_play_again)

# ── Connection ────────────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	_register_self()
	log_line("Hosting on port %d" % PORT)

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_peer_connected(id: int) -> void:
	log_line("Peer %d joined" % id)
	# Send existing player data to the new peer
	if multiplayer.is_server():
		for pid in _players:
			var p: CharacterBody2D = _players[pid]
			send_existing_player.rpc_id(id, pid, p.player_name_str, p.player_color, _scores.get(pid, 0))

func _on_peer_disconnected(id: int) -> void:
	log_line("Peer %d left" % id)
	_scores.erase(id)
	if _players.has(id):
		_players[id].queue_free()
		_players.erase(id)
	_refresh_scoreboard()

func _on_connected_to_server() -> void:
	log_line("Connected. My ID=%d" % multiplayer.get_unique_id())
	register_me.rpc_id(1, "P%d" % multiplayer.get_unique_id())

func _on_server_disconnected() -> void:
	log_line("Server disconnected.")
	_cleanup_game()
	multiplayer.multiplayer_peer = null
	_show_lobby()

# ── Player registration ───────────────────────────────────────────────────

func _register_self() -> void:
	var id := multiplayer.get_unique_id()
	_scores[id] = 0
	_spawn_player_for(id, "P%d" % id, _player_colors[0])

@rpc("any_peer", "call_remote", "reliable")
func register_me(p_name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var idx := _players.size()
	var color: Color = _player_colors[idx % _player_colors.size()]
	_scores[id] = 0
	_spawn_player_for(id, p_name, color)
	new_player_broadcast.rpc(id, p_name, color)

@rpc("authority", "call_local", "reliable")
func new_player_broadcast(id: int, _p_name: String, _color: Color) -> void:
	if not _players.has(id):
		_scores[id] = 0
	_refresh_scoreboard()

@rpc("authority", "call_remote", "reliable")
func send_existing_player(id: int, _p_name: String, _color: Color, score: int) -> void:
	_scores[id] = score
	_refresh_scoreboard()

# ── Spawning ──────────────────────────────────────────────────────────────

func _spawn_player_for(id: int, p_name: String, color: Color) -> void:
	var idx := _players.size()
	$Arena/PlayerSpawner.spawn({
		"peer_id": id, "name": p_name, "color": color,
		"position": Vector2(80 + idx * 150, 230),
	})

func _spawn_player_node(data: Dictionary) -> Node:
	var scene := preload("res://lessons/lesson_10_mini_game/game_player.tscn")
	var p = scene.instantiate()
	p.name = "Player_%d" % data["peer_id"]
	p.player_id = data["peer_id"]
	p.player_name_str = data["name"]
	p.player_color = data["color"]
	p.position = data["position"]
	p.set_multiplayer_authority(data["peer_id"])
	_players[data["peer_id"]] = p
	if multiplayer.is_server():
		p.died.connect(_on_player_died)
	return p

# ── Coins ─────────────────────────────────────────────────────────────────

func _spawn_coins() -> void:
	for i in COIN_COUNT:
		var pos := Vector2(
			randf_range(50, 730),
			randf_range(50, 430)
		)
		$Arena/CoinSpawner.spawn({ "index": i, "position": pos })

func _spawn_coin_node(data: Dictionary) -> Node:
	# Node2D so position stays in same coordinate space as CharacterBody2D players
	var coin := Node2D.new()
	coin.name = "Coin_%d" % data["index"]
	coin.position = data["position"]
	# Visual child — offset so it's centered on the node origin
	var rect := ColorRect.new()
	rect.size = Vector2(18, 18)
	rect.position = Vector2(-9, -9)
	rect.color = Color.YELLOW
	coin.add_child(rect)
	_coins.append(coin)
	return coin

# ── Game flow ─────────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		log_line("Only server starts")
		return
	if _players.size() < 1:
		log_line("Need at least 1 player connected")
		return
	begin_game.rpc()

@rpc("authority", "call_local", "reliable")
func begin_game() -> void:
	_state = State.PLAYING
	_show_game()
	log_line("GAME START!")
	if multiplayer.is_server():
		_spawn_coins()

func _physics_process(_delta: float) -> void:
	if _state != State.PLAYING or not multiplayer.is_server():
		return
	# Server checks coin pickups
	for player_id in _players:
		var player: CharacterBody2D = _players[player_id]
		for coin in _coins.duplicate():
			if not is_instance_valid(coin):
				continue
			if player.position.distance_to(coin.position) < 32:
				# Pickup!
				coin.queue_free()
				_coins.erase(coin)
				_scores[player_id] = _scores.get(player_id, 0) + 1
				award_point.rpc(player_id, _scores[player_id])
				if _scores[player_id] >= COINS_TO_WIN:
					declare_winner.rpc(player_id)
					return
	# Respawn coins if all taken
	if _coins.is_empty():
		_spawn_coins()

@rpc("authority", "call_local", "reliable")
func award_point(pid: int, new_score: int) -> void:
	_scores[pid] = new_score
	_refresh_scoreboard()
	log_line("P%d scored! (%d pts)" % [pid, new_score])

@rpc("authority", "call_local", "reliable")
func declare_winner(pid: int) -> void:
	_state = State.GAME_OVER
	var is_me := pid == multiplayer.get_unique_id()
	$UI/GameOver/WinnerLabel.text = "P%d wins!%s" % [pid, "\nYOU WIN!" if is_me else ""]
	_show_game_over()
	log_line("GAME OVER! Winner: P%d" % pid)

func _on_player_died(pid: int) -> void:
	log_line("P%d eliminated!" % pid)

func _on_play_again() -> void:
	if not multiplayer.is_server():
		return
	_cleanup_game()
	reset_game.rpc()

@rpc("authority", "call_local", "reliable")
func reset_game() -> void:
	_cleanup_game()
	_show_lobby()

func _cleanup_game() -> void:
	for coin in _coins:
		if is_instance_valid(coin):
			coin.queue_free()
	_coins.clear()
	for p in _players.values():
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	for id in _scores:
		_scores[id] = 0
	_state = State.LOBBY

# ── UI ────────────────────────────────────────────────────────────────────

func _show_lobby() -> void:
	$UI/Lobby.visible = true
	$UI/Game.visible = false
	$UI/GameOver.visible = false

func _show_game() -> void:
	$UI/Lobby.visible = false
	$UI/Game.visible = true
	$UI/GameOver.visible = false

func _show_game_over() -> void:
	$UI/Lobby.visible = false
	$UI/Game.visible = false
	$UI/GameOver.visible = true

func _refresh_scoreboard() -> void:
	var txt := ""
	for id in _scores:
		var name_str: String = _players[id].player_name_str if _players.has(id) else "P%d" % id
		txt += "%s: %d pts\n" % [name_str, _scores[id]]
	$UI/Game/Scoreboard.text = txt

func log_line(text: String) -> void:
	$UI/Lobby/Log.append_text(text + "\n")
