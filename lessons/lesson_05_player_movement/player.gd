## LESSON 05: Player Movement — Input Authority Pattern
##
## This is the CORRECT pattern for multiplayer player controllers:
##   1. Each player owns one node (set_multiplayer_authority)
##   2. Only the authority reads Input
##   3. MultiplayerSynchronizer sends position to all peers
##   4. Remote players just render the received position
##
## Additional concepts here:
##   - Sending input via RPC to server (server-move pattern, lesson preview)
##   - Visual name tag above player
##   - Distinguishing local vs remote visually

extends CharacterBody2D

@export var player_id: int = 0
@export var player_color: Color = Color.WHITE

const SPEED := 180.0

func _ready() -> void:
	$Sprite.color = player_color

	# Tint local player brighter
	if is_multiplayer_authority():
		$Sprite.color = player_color.lightened(0.3)
		$NameTag.text = "YOU (id=%d)" % player_id
	else:
		$NameTag.text = "P%d" % player_id

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return  # Remote players: position comes from MultiplayerSynchronizer

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()
