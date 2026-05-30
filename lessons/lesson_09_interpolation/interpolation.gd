## LESSON 09: Lag, Interpolation, and Smooth Movement
##
## Concepts:
##   - Why movement looks choppy without interpolation:
##     sync_interval=0.1 → 10 position updates/sec → visible jumps at 60fps
##   - MultiplayerSynchronizer interpolation: built-in position smoothing
##     Set replication_interval > 0 AND interpolation = true
##   - The trade-off: interpolation adds latency equal to ~1 sync interval
##   - unreliable_ordered channel: best for position (drop stale packets)
##   - Simulated lag: add artificial delay to see the difference visually
##
## Controls in this lesson:
##   - Toggle between slow (0.2s) and fast (0.033s) sync rates
##   - Toggle interpolation ON/OFF on the MultiplayerSynchronizer
##   - Add simulated lag to see how it affects smoothness

extends Node2D

const PORT := 7008

var _players: Dictionary = {}
var _simulated_lag_ms := 0

func _ready() -> void:
	$UI/VBox/Row1/HostBtn.pressed.connect(_on_host_pressed)
	$UI/VBox/Row1/JoinBtn.pressed.connect(_on_join_pressed)
	$UI/VBox/Row1/DisconnectBtn.pressed.connect(_on_disconnect_pressed)
	$UI/VBox/Row2/SlowSyncBtn.pressed.connect(_set_slow_sync)
	$UI/VBox/Row2/FastSyncBtn.pressed.connect(_set_fast_sync)
	$UI/VBox/Row2/ToggleInterpBtn.pressed.connect(_toggle_interpolation)
	$UI/VBox/LagRow/LagSlider.value_changed.connect(_on_lag_changed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): request_spawn.rpc_id(1))

	$PlayArea/Spawner.spawn_function = _do_spawn

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	_spawn_for(1)
	log_line("Hosting. Move with arrows.")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer

func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id: int) -> void:
	log_line("Peer %d joined" % id)

func _on_peer_disconnected(id: int) -> void:
	if _players.has(id):
		_players[id].queue_free()
		_players.erase(id)

@rpc("any_peer", "call_remote", "reliable")
func request_spawn() -> void:
	_spawn_for(multiplayer.get_remote_sender_id())

func _spawn_for(peer_id: int) -> void:
	var idx := _players.size()
	$PlayArea/Spawner.spawn({
		"peer_id": peer_id,
		"color": Color.from_hsv(idx * 0.35, 0.7, 0.9),
		"position": Vector2(100 + idx * 200, 210),
	})

func _do_spawn(data: Dictionary) -> Node:
	var scene := preload("res://lessons/lesson_09_interpolation/interp_player.tscn")
	var p = scene.instantiate()
	p.name = "P_%d" % data["peer_id"]
	p.player_id = data["peer_id"]
	p.player_color = data["color"]
	p.position = data["position"]
	p.set_multiplayer_authority(data["peer_id"])
	_players[data["peer_id"]] = p
	return p

# ── Sync rate controls ────────────────────────────────────────────────────

func _set_slow_sync() -> void:
	# 0.2 second intervals = 5 updates/sec → very choppy without interpolation
	_set_all_sync_intervals(0.2)
	log_line("Sync rate: SLOW (0.2s = 5/sec). Choppy without interpolation.")

func _set_fast_sync() -> void:
	# 0.033 second intervals ≈ 30 updates/sec → smoother but more bandwidth
	_set_all_sync_intervals(0.033)
	log_line("Sync rate: FAST (0.033s ≈ 30/sec).")

func _set_all_sync_intervals(interval: float) -> void:
	for p in _players.values():
		if p.has_node("Sync"):
			p.get_node("Sync").replication_interval = interval
			p.sync_interval = interval  # player uses this for lerp timing

# ── Interpolation toggle ──────────────────────────────────────────────────

func _toggle_interpolation() -> void:
	for p in _players.values():
		p.use_interpolation = not p.use_interpolation
		log_line("Interpolation = %s" % p.use_interpolation)
		log_line("  ON  → lerp toward net_pos each frame (smooth, ~1 interval behind)")
		log_line("  OFF → snap to net_pos each frame (choppy at slow sync rate)")

func _on_lag_changed(value: float) -> void:
	_simulated_lag_ms = int(value)
	log_line("Simulated lag: %d ms (visual only — actual ENet lag not simulated here)" % _simulated_lag_ms)

## KEY TAKEAWAYS:
##
## 1. replication_interval = 0      → sync every physics tick (most bandwidth)
##    replication_interval = 0.1    → 10/sec (less bandwidth, needs interpolation)
##
## 2. With interpolation OFF + slow sync → see the "teleporting" jumps
##    With interpolation ON + slow sync  → smooth movement, but ~1 interval behind
##
## 3. For position: use "unreliable_ordered" channel
##    For important events (kill, pickup): use "reliable"
##
## 4. Real lag compensation is complex: snapshot buffers, rollback, rewind physics
##    For most indie games: interpolation + authoritative server is enough

func log_line(text: String) -> void:
	$UI/VBox/Log.append_text(text + "\n")
