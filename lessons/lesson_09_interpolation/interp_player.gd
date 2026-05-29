## Player used in Lesson 09 — demonstrates interpolation vs none

extends ColorRect

@export var player_id: int = 0
@export var player_color: Color = Color.WHITE
@export var use_interpolation: bool = true

const SPEED := 150.0

# For manual interpolation (when MultiplayerSynchronizer interpolation is off)
var _display_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO
var _last_sync_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	color = player_color
	$Label.text = "P%d" % player_id
	_display_pos = position
	_target_pos = position

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		position += dir * SPEED * delta
		position = position.clamp(Vector2.ZERO, Vector2(720, 420))
	elif not use_interpolation:
		# RAW mode: snap directly to synced position — choppy at low sync rate
		pass  # position set directly by MultiplayerSynchronizer
	else:
		# MANUAL INTERPOLATION: smooth between last two known positions
		# This is what MultiplayerSynchronizer does internally when interpolation=true
		_display_pos = _display_pos.lerp(position, min(delta * 20.0, 1.0))
		# Visually show interpolated pos (for demo we show raw via position,
		# but in a real setup you'd move a visual child node to _display_pos)
