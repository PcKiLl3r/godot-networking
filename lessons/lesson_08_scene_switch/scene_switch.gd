## LESSON 08: Scene Switching in Multiplayer
##
## Concepts:
##   - Changing scenes across ALL peers simultaneously
##   - Why: get_tree().change_scene_to_file() only affects local peer
##   - Pattern: server decides to switch → broadcasts RPC → all peers switch
##   - Keeping the multiplayer peer alive across scene changes
##   - Using a persistent "Network Manager" autoload (shown here inline)
##   - Loading screen: show UI before/after scene swap
##
## Key rule: The MultiplayerAPI lives on the SceneTree, NOT in any scene.
## So it survives scene changes automatically. You don't need to reconnect.

extends Control

const PORT := 7007

func _ready() -> void:
	$VBox/Buttons/HostBtn.pressed.connect(_on_host_pressed)
	$VBox/Buttons/JoinBtn.pressed.connect(_on_join_pressed)
	$VBox/Buttons/DisconnectBtn.pressed.connect(_on_disconnect_pressed)
	$VBox/SceneButtons/GoToGameBtn.pressed.connect(_on_go_to_game)
	$VBox/SceneButtons/GoToLobbyBtn.pressed.connect(_on_go_to_lobby)

	multiplayer.peer_connected.connect(func(id): log_line("Peer %d joined" % id))
	multiplayer.connected_to_server.connect(func(): log_line("Connected. ID=%d" % multiplayer.get_unique_id()))

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	log_line("Hosting.")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer = null
	log_line("Disconnected.")

# ── Scene switching ───────────────────────────────────────────────────────

func _on_go_to_game() -> void:
	if not multiplayer.is_server():
		log_line("Only server triggers scene changes")
		return
	log_line("Server ordering all peers: go to 'game' scene")
	# In a real project, use an actual scene path. Here we just show the flow.
	switch_scene.rpc("game")

func _on_go_to_lobby() -> void:
	if not multiplayer.is_server():
		log_line("Only server triggers scene changes")
		return
	log_line("Server ordering return to lobby")
	switch_scene.rpc("lobby")

@rpc("authority", "call_local", "reliable")
func switch_scene(scene_name: String) -> void:
	log_line("Switching to '%s' scene..." % scene_name)

	# Show a loading indicator (in real game: overlay CanvasLayer)
	$VBox/Status.text = "Loading: %s..." % scene_name

	# IMPORTANT: multiplayer peer SURVIVES scene change.
	# The ENetMultiplayerPeer is on the SceneTree, not in the scene.
	# So connections stay alive automatically.

	# In a real project you would do:
	#   get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene_name)
	#
	# The new scene will find the existing multiplayer via:
	#   multiplayer.get_unique_id()  → still valid
	#   multiplayer.is_server()      → still valid
	#
	# Since we don't have a second scene here, simulate it:
	await get_tree().process_frame
	$VBox/Status.text = "Now in scene: %s (peers: %s)" % [scene_name, multiplayer.get_peers()]
	log_line("Scene switch complete. Multiplayer still alive: peer=%d" % multiplayer.get_unique_id())

# ── BEST PRACTICE: Network Manager Autoload ───────────────────────────────
##
## In a real project, create an Autoload (Project → Autoloads) called NetworkManager:
##
##   # network_manager.gd  (autoload)
##   extends Node
##
##   signal player_connected(id)
##   signal player_disconnected(id)
##   signal connection_failed
##
##   var players := {}
##
##   func _ready():
##       multiplayer.peer_connected.connect(_on_peer_connected)
##       multiplayer.peer_disconnected.connect(_on_peer_disconnected)
##
##   func host(port: int) -> void:
##       var peer := ENetMultiplayerPeer.new()
##       peer.create_server(port)
##       multiplayer.multiplayer_peer = peer
##
##   func join(ip: String, port: int) -> void:
##       var peer := ENetMultiplayerPeer.new()
##       peer.create_client(ip, port)
##       multiplayer.multiplayer_peer = peer
##
##   func disconnect_network() -> void:
##       multiplayer.multiplayer_peer = null
##       players.clear()
##
##   func _on_peer_connected(id): player_connected.emit(id)
##   func _on_peer_disconnected(id): player_disconnected.emit(id)
##
## Then ANY scene just uses NetworkManager.host(), NetworkManager.players, etc.
## No scene needs to recreate the peer — it's always alive in the autoload.

func log_line(text: String) -> void:
	$VBox/Log.append_text(text + "\n")
