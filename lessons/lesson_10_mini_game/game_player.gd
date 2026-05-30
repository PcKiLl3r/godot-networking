## Lesson 10: Mini-game player node
## Combines: authority-based input, MultiplayerSynchronizer, health sync

extends CharacterBody2D

@export var player_id: int = 0
@export var player_color: Color = Color.WHITE
@export var player_name_str: String = "?"
@export var health: int = 3  # synced via MultiplayerSynchronizer

const SPEED := 160.0

signal died(peer_id)

func _ready() -> void:
	$Sprite.color = player_color
	$NameLabel.text = player_name_str + ("\n[YOU]" if is_multiplayer_authority() else "")
	_update_health_display()

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()
	# Clamp to arena
	position = position.clamp(Vector2(10, 10), Vector2(750, 450))

# Called by server only — reduces health and syncs via property sync
func take_damage() -> void:
	if not multiplayer.is_server():
		return
	health -= 1
	_update_health_display()
	if health <= 0:
		died.emit(player_id)

func _update_health_display() -> void:
	$HealthLabel.text = "HP: " + "♥".repeat(max(health, 0))
