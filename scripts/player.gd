extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $jumpSound

const SPEED = 300.0
const JUMP_VELOCITY = -750.0
const GLITCH_SOUND: AudioStream = preload("res://assets/audio/sfx/456779__spaciecat__glitch-6-spindown.wav")

var lives := 0
var glitches_enabled := false
var _rng := RandomNumberGenerator.new()
var _trail_timer := 0.0
var _wrong_sprite_timer := 2.5
var _wrong_sprite_duration := 0.0
var _underflow_glitch := 0.0
var _stutter_timer := 0.0
var _stutter_hold := 0.0


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if not glitches_enabled:
		return

	if _stutter_hold > 0.0:
		_stutter_hold -= delta
		animated_sprite_2d.speed_scale = 0.0
		if _stutter_hold <= 0.0:
			animated_sprite_2d.speed_scale = _rng.randf_range(0.75, 1.25)
	else:
		_stutter_timer -= delta
		if _stutter_timer <= 0.0:
			_stutter_hold = _rng.randf_range(0.035, 0.09)
			_stutter_timer = _rng.randf_range(0.22, 0.62)

	if _underflow_glitch > 0.0:
		_underflow_glitch -= delta
		animated_sprite_2d.modulate = Color(
			_rng.randf_range(0.45, 1.0),
			_rng.randf_range(0.2, 1.0),
			_rng.randf_range(0.45, 1.0),
			1.0
		)
		animated_sprite_2d.position = Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-4.0, 4.0))
	else:
		animated_sprite_2d.modulate = Color.WHITE
		animated_sprite_2d.position = Vector2.ZERO

	_trail_timer -= delta
	if _trail_timer <= 0.0 and (velocity.length() > 20.0 or _underflow_glitch > 0.0):
		_spawn_sprite_trail()
		_trail_timer = 0.05 if _underflow_glitch > 0.0 else 0.11


func activate_glitches() -> void:
	glitches_enabled = true
	jump_sound.stream = GLITCH_SOUND
	_stutter_timer = _rng.randf_range(0.2, 0.5)


func apply_life_underflow(amount: int = 1) -> void:
	lives -= amount
	if lives < 0:
		_underflow_glitch = 8.0


func _spawn_sprite_trail() -> void:
	var frame_texture := animated_sprite_2d.sprite_frames.get_frame_texture(
		animated_sprite_2d.animation,
		animated_sprite_2d.frame
	)
	if frame_texture == null:
		return

	var trail := Sprite2D.new()
	trail.texture = frame_texture
	trail.flip_h = animated_sprite_2d.flip_h
	trail.texture_filter = animated_sprite_2d.texture_filter
	trail.modulate = Color(0.1, 0.95, 1.0, 0.38) if _rng.randf() < 0.5 else Color(1.0, 0.15, 0.65, 0.34)
	trail.z_index = animated_sprite_2d.z_index - 1
	get_tree().current_scene.add_child(trail)
	trail.global_transform = animated_sprite_2d.global_transform
	var fade := create_tween()
	fade.tween_property(trail, "modulate:a", 0.0, 0.42)
	fade.tween_callback(trail.queue_free)


func _physics_process(delta: float) -> void:
	if glitches_enabled:
		_wrong_sprite_duration = maxf(_wrong_sprite_duration - delta, 0.0)
		_wrong_sprite_timer -= delta
		if _wrong_sprite_duration == 0.0 and _wrong_sprite_timer <= 0.0:
			var wrong_animations := ["death", "iddle", "running", "jumpping"]
			if is_on_floor():
				wrong_animations = ["death", "jumpping"]
			else:
				wrong_animations = ["death", "iddle", "running"]
			animated_sprite_2d.play(wrong_animations[_rng.randi_range(0, wrong_animations.size() - 1)])
			animated_sprite_2d.scale = Vector2(_rng.randf_range(1.4, 2.2), _rng.randf_range(1.4, 2.2))
			_wrong_sprite_duration = _rng.randf_range(0.18, 0.42)
			_wrong_sprite_timer = _rng.randf_range(2.0, 4.5)
		elif _wrong_sprite_duration == 0.0:
			animated_sprite_2d.scale = Vector2.ONE
			if velocity.x > 1.0 or velocity.x < -1.0:
				animated_sprite_2d.play("running")
			else:
				animated_sprite_2d.play("iddle")
	else:
		if velocity.x > 1 or velocity.x < -1:
			animated_sprite_2d.animation = "running"
		else:
			animated_sprite_2d.animation = "iddle"

	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.animation = "jumpping"

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if glitches_enabled:
			jump_sound.pitch_scale = _rng.randf_range(0.55, 1.7)
		jump_sound.play()

	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	if direction == 1.0:
		animated_sprite_2d.flip_h = false
	elif direction == -1.0:
		animated_sprite_2d.flip_h = true
