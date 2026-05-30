## Player for Lesson 09 — Snapshot Interpolation
##
## Pattern: snapshot interpolation
##   When a new net_pos arrives → record where we WERE (_snap_from)
##   and where we need to GO (_snap_to), reset a timer.
##   Each frame: t = timer / sync_interval → lerp from→to
##   Result: perfectly smooth movement, exactly 1 interval behind.
##
## Contrast with OFF: raw snap → visible 30px teleport every 0.2s.

extends ColorRect

@export var player_id: int = 0
@export var player_color: Color = Color.WHITE

# Synced property — authority writes this, remotes read it
@export var net_pos: Vector2 = Vector2.ZERO:
	set(v):
		net_pos = v
		if not is_multiplayer_authority():
			_snap_from = position       # start from current visual pos
			_snap_to   = v              # move toward new received pos
			_snap_t    = 0.0            # reset timer

var use_interpolation: bool = false

# Snapshot interpolation state
var _snap_from: Vector2 = Vector2.ZERO
var _snap_to:   Vector2 = Vector2.ZERO
var _snap_t:    float   = 0.0
var sync_interval: float = 0.2         # kept in sync with the Sync node interval

const SPEED := 150.0

func _ready() -> void:
	color = player_color
	$Label.text = "P%d%s" % [player_id, "\n[YOU]" if is_multiplayer_authority() else ""]
	net_pos = position
	_snap_from = position
	_snap_to   = position

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		return
	if use_interpolation:
		_snap_t = min(_snap_t + delta, sync_interval)
		var t := _snap_t / sync_interval if sync_interval > 0.0 else 1.0
		position = _snap_from.lerp(_snap_to, t)
	else:
		position = net_pos  # raw snap — jumpy at slow sync rates

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += dir * SPEED * delta
	position = position.clamp(Vector2.ZERO, Vector2(720, 420))
	net_pos = position
