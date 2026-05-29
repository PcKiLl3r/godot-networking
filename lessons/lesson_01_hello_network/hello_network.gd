## LESSON 01: Hello Network
##
## Concepts:
##   - ENetMultiplayerPeer: Godot's built-in UDP networking transport
##   - create_server(port, max_clients): start listening for connections
##   - create_client(ip, port): connect to a server
##   - multiplayer.multiplayer_peer: assigning peer activates the network
##   - multiplayer.get_unique_id(): your peer ID. Server is always 1.
##   - Signals: peer_connected, peer_disconnected, connected_to_server, connection_failed
##   - First @rpc: a function marked @rpc can be called on remote peers
##
## Try it:
##   1. Run two instances (Debug → Run Second Instance)
##   2. Instance A: click "Host Server"
##   3. Instance B: click "Join as Client"
##   4. Both click "Send RPC Message" — watch the log on both sides

extends Control

const DEFAULT_PORT := 7000
const MAX_CLIENTS := 8

func _ready() -> void:
	# Bind UI buttons to functions
	$VBox/Buttons/HostBtn.pressed.connect(_on_host_pressed)
	$VBox/Buttons/JoinBtn.pressed.connect(_on_join_pressed)
	$VBox/Buttons/DisconnectBtn.pressed.connect(_on_disconnect_pressed)
	$VBox/SendBtn.pressed.connect(_on_send_pressed)

	# These signals fire on ALL peers
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# These only fire on clients (not the server)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	# server_disconnected fires on clients when they lose the server
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var port := int($VBox/PortRow/PortInput.text)
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		log_line("ERROR: Could not start server on port %d (err=%d)" % [port, err])
		return
	multiplayer.multiplayer_peer = peer
	# Server always gets ID = 1
	log_line("Server started on :%d  |  My ID = %d" % [port, multiplayer.get_unique_id()])
	set_status("SERVER (ID=1)")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var ip: String = $VBox/IPRow/IPInput.text
	var port := int($VBox/PortRow/PortInput.text)
	var err := peer.create_client(ip, port)
	if err != OK:
		log_line("ERROR: Could not connect to %s:%d (err=%d)" % [ip, port, err])
		return
	multiplayer.multiplayer_peer = peer
	log_line("Connecting to %s:%d ..." % [ip, port])
	set_status("Connecting...")

func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer = null  # null = offline, clears all connections
	log_line("Disconnected.")
	set_status("Offline")

func _on_send_pressed() -> void:
	if not multiplayer.has_multiplayer_peer():
		log_line("Not connected — host or join first.")
		return
	var msg := "Hello from peer %d!" % multiplayer.get_unique_id()
	# .rpc() with no arguments: calls on ALL connected peers + self (because call_local)
	receive_message.rpc(msg)

# --- Multiplayer signals ---

func _on_peer_connected(id: int) -> void:
	# Fires on server when a client joins, AND on existing clients when a new peer joins
	log_line(">>> Peer connected: ID=%d" % id)

func _on_peer_disconnected(id: int) -> void:
	log_line("<<< Peer disconnected: ID=%d" % id)

func _on_connected_to_server() -> void:
	# Fires on CLIENT only, once TCP/UDP handshake completes
	log_line("Connected to server! My ID = %d" % multiplayer.get_unique_id())
	set_status("CLIENT (ID=%d)" % multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	log_line("Connection FAILED. Is the server running?")
	set_status("Connection Failed")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	log_line("Server disconnected.")
	set_status("Offline")
	multiplayer.multiplayer_peer = null

# --- The first RPC ---
#
# @rpc parameters (in order):
#   1. WHO CAN CALL IT:  "any_peer" | "authority"
#   2. LOCAL BEHAVIOR:   "call_local" | "call_remote"
#   3. RELIABILITY:      "reliable" | "unreliable" | "unreliable_ordered"
#   4. CHANNEL (int):    optional, default 0
#
# "any_peer"   = any connected peer may invoke this remotely
# "call_local" = also call on the sender's own machine (not just remotes)
# "reliable"   = guaranteed delivery + ordering (like TCP)

@rpc("any_peer", "call_local", "reliable")
func receive_message(msg: String) -> void:
	# get_remote_sender_id() returns who sent this RPC (0 = local call)
	var sender := multiplayer.get_remote_sender_id()
	var label := "local" if sender == multiplayer.get_unique_id() else "peer %d" % sender
	log_line("[RPC from %s] %s" % [label, msg])

# --- UI helpers ---

func log_line(text: String) -> void:
	$VBox/Log.append_text(text + "\n")

func set_status(text: String) -> void:
	$VBox/Status.text = "Status: " + text
