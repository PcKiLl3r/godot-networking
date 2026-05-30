## LESSON 02: RPCs — Remote Procedure Calls
##
## Concepts:
##   - @rpc modes: who can CALL it (any_peer vs authority)
##   - call_local vs call_remote: does sender also run it locally?
##   - reliable vs unreliable vs unreliable_ordered
##   - rpc() vs rpc_id(peer_id, ...): broadcast vs targeted
##   - get_remote_sender_id(): who invoked this RPC
##   - set_multiplayer_authority(id): which peer "owns" a node
##   - is_multiplayer_authority(): am I the owner?
##
## Try it:
##   1. Host in instance A, join in instance B
##   2. Try each button — watch what fires where
##   3. Notice "authority-only" button only works from the server

extends Control

const PORT := 7001

func _ready() -> void:
	$VBox/Buttons/HostBtn.pressed.connect(_on_host_pressed)
	$VBox/Buttons/JoinBtn.pressed.connect(_on_join_pressed)
	$VBox/Buttons/DisconnectBtn.pressed.connect(_on_disconnect_pressed)

	$VBox/RPC1Btn.pressed.connect(_demo_any_peer_call_local)
	$VBox/RPC2Btn.pressed.connect(_demo_any_peer_call_remote)
	$VBox/RPC3Btn.pressed.connect(_demo_authority_only)
	$VBox/RPC4Btn.pressed.connect(_demo_unreliable)
	$VBox/RPC5Btn.pressed.connect(_demo_targeted)

	multiplayer.peer_connected.connect(func(id): log_line("+ peer %d" % id))
	multiplayer.peer_disconnected.connect(func(id): log_line("- peer %d" % id))
	multiplayer.connected_to_server.connect(func(): log_line("Connected. My ID=%d" % multiplayer.get_unique_id()))

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 8)
	multiplayer.multiplayer_peer = peer
	log_line("Server. ID=1")

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	log_line("Connecting...")

func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer = null
	log_line("Offline")

# ─────────────────────────────────────────────
# DEMO 1: any_peer + call_local
# ─────────────────────────────────────────────
# "any_peer" = ANY connected peer can invoke this
# "call_local" = sender's machine ALSO runs the function body
# Result: fires on ALL machines including sender
func _demo_any_peer_call_local() -> void:
	log_line("[DEMO 1] Calling rpc_any_peer_local_reliable.rpc()")
	rpc_any_peer_local_reliable.rpc("any_peer + call_local")

@rpc("any_peer", "call_local", "reliable")
func rpc_any_peer_local_reliable(label: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	log_line("  RECV [%s] sender=%s" % [label, "local" if sender == 0 else str(sender)])

# ─────────────────────────────────────────────
# DEMO 2: any_peer + call_remote (default)
# ─────────────────────────────────────────────
# "call_remote" = only REMOTE peers run it, NOT the sender
# Use for: sending data you already have locally (avoid duplication)
func _demo_any_peer_call_remote() -> void:
	log_line("[DEMO 2] Calling rpc_any_peer_remote.rpc() — won't fire locally")
	rpc_any_peer_remote.rpc("any_peer + call_remote")

@rpc("any_peer", "call_remote", "reliable")
func rpc_any_peer_remote(label: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	log_line("  RECV [%s] from peer %d" % [label, sender])

# ─────────────────────────────────────────────
# DEMO 3: authority only
# ─────────────────────────────────────────────
# "authority" = ONLY the node's authority peer can call this remotely
# By default, server (ID=1) is authority of all nodes
# Clients calling rpc() on an authority-only function → rejected
# Use for: client→server messages you want to restrict
func _demo_authority_only() -> void:
	if not multiplayer.has_multiplayer_peer():
		log_line("[DEMO 3] Not connected — host or join first.")
		return
	if not multiplayer.is_server():
		# Don't call the RPC — engine would error. Explain instead.
		log_line("[DEMO 3] BLOCKED: you are a client (id=%d), not the authority." % multiplayer.get_unique_id())
		log_line("         @rpc(\"authority\") = only peer with authority (server=1) may call this.")
		log_line("         Attempting it would cause: 'RPC not allowed, mode is authority'")
		return
	log_line("[DEMO 3] I am server/authority (id=1) — calling authority_only.rpc()")
	authority_only.rpc("from authority")

@rpc("authority", "call_local", "reliable")
func authority_only(label: String) -> void:
	log_line("  RECV [%s] sender=%d" % [label, multiplayer.get_remote_sender_id()])

# ─────────────────────────────────────────────
# DEMO 4: unreliable
# ─────────────────────────────────────────────
# "unreliable" = fire-and-forget UDP, no retransmit, may arrive out of order
# Use for: position updates (stale data useless anyway), high-frequency sends
# "unreliable_ordered" = no retransmit but per-channel ordering guaranteed
func _demo_unreliable() -> void:
	log_line("[DEMO 4] Sending 5 unreliable packets (may arrive out of order)")
	for i in 5:
		rpc_unreliable_demo.rpc(i)

@rpc("any_peer", "call_local", "unreliable")
func rpc_unreliable_demo(seq: int) -> void:
	log_line("  RECV unreliable packet #%d" % seq)

# ─────────────────────────────────────────────
# DEMO 5: rpc_id — targeted, not broadcast
# ─────────────────────────────────────────────
# rpc_id(peer_id, args...) sends ONLY to that specific peer
# Server uses 1 as its own ID. Clients: multiplayer.get_unique_id()
# Special peer ID 0 = broadcast to all (same as .rpc() with no ID)
# Special peer ID 1 = always the server
func _demo_targeted() -> void:
	if not multiplayer.has_multiplayer_peer():
		log_line("Not connected")
		return
	# Always send to the server (ID=1), even from a client
	var target := 1
	log_line("[DEMO 5] Sending targeted rpc_id to peer %d" % target)
	rpc_targeted.rpc_id(target, "targeted to peer %d" % target)

@rpc("any_peer", "call_local", "reliable")
func rpc_targeted(label: String) -> void:
	log_line("  RECV targeted: [%s]" % label)

# ─────────────────────────────────────────────
# SUMMARY TABLE (read this!)
# ─────────────────────────────────────────────
# @rpc mode     | Who can call remotely     | Typical use
# any_peer      | Any connected peer        | chat, player actions
# authority     | Only the authority peer   | server→client updates
#
# call_local    | Sender also runs locally  | when sender needs same result
# call_remote   | Only remotes run it       | avoid duplicate local logic
#
# reliable      | Guaranteed, ordered       | important game events
# unreliable    | UDP fire-and-forget       | position/rotation spam
# unrel_ordered | Ordered within channel    | state snapshots

func log_line(text: String) -> void:
	$VBox/Log.append_text(text + "\n")
