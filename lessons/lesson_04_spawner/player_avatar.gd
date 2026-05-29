## Player avatar spawned by MultiplayerSpawner in lesson 04
## Each peer gets one of these for every player in the game.
## Only the authority peer moves their own avatar.

extends ColorRect

@export var player_name: String = "?"
@export var player_color: Color = Color.WHITE

func _ready() -> void:
	color = player_color
	# Show whose avatar this is
	$Label.text = player_name + ("\n[YOU]" if is_multiplayer_authority() else "")

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return  # Only move your own avatar

	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"):  dir.x -= 1
	if Input.is_action_pressed("ui_down"):  dir.y += 1
	if Input.is_action_pressed("ui_up"):    dir.y -= 1

	position += dir * 150.0 * delta
	# Clamp stays reasonable (arena is ~500x300)
	position = position.clamp(Vector2.ZERO, Vector2(460, 260))
