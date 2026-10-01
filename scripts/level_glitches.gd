extends Node2D

const GLITCH_SOUND: AudioStream = preload("res://assets/audio/sfx/456779__spaciecat__glitch-6-spindown.wav")
const ORIGINAL_LEVEL_RIGHT_EDGE := 1272.0
const TILE_WORLD_SIZE := 48.0

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player: CharacterBody2D = $CharacterBody2D

var _rng := RandomNumberGenerator.new()
var _status_label: Label
var _ambient_sound: AudioStreamPlayer2D
var _glitches_active := false
var _ambient_timer := 8.0
var _fake_floor_gaps: Array[Rect2] = []
var _moving_platforms: Array[Dictionary] = []
var _crash_event_shown := false
var _goal_reached := false


func _ready() -> void:
	_rng.randomize()
	_create_fake_collision_gap()


func _process(delta: float) -> void:
	if not _glitches_active:
		var fell_through_fake_floor := false
		for gap in _fake_floor_gaps:
			if gap.has_point(player.global_position) and player.velocity.y > 0.0:
				fell_through_fake_floor = true
				break
		if fell_through_fake_floor:
			_activate_glitches()
		return

	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_sound.pitch_scale = _rng.randf_range(0.55, 1.7)
		_ambient_sound.play()
		_ambient_timer = _rng.randf_range(8.0, 14.0)

func _physics_process(_delta: float) -> void:
	var elapsed := float(Time.get_ticks_msec()) / 1000.0
	for platform_data in _moving_platforms:
		var platform: AnimatableBody2D = platform_data["body"]
		var origin: Vector2 = platform_data["origin"]
		var phase: float = platform_data["phase"]
		platform.position = origin + Vector2(sin(elapsed * 1.1 + phase) * 20.0, sin(elapsed * 0.7 + phase) * 8.0)

func _activate_glitches() -> void:
	_glitches_active = true
	tile_map_layer.collision_enabled = false
	player.call("activate_glitches")
	player.call("apply_life_underflow", 1)
	_add_follow_camera()
	_add_trailing_skybox()
	_build_lower_obstacles()
	_build_lower_level()
	_add_status_hud()
	_add_glitch_audio()
	_add_goal()
	_status_label.text = "LIVES: %s   BUILD: CORRUPTED" % player.get("lives")


func _add_follow_camera() -> void:
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	player.add_child(camera)


func _add_trailing_skybox() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -1
	add_child(sky_layer)

	var frame_paths := [
		"res://assets/backgrounds/static/resized_tower_collapse_1.png",
		"res://assets/backgrounds/static/resized_tower_collapse_2.png",
		"res://assets/backgrounds/static/resized_tower_collapse_3.png"
	]
	var offsets := [Vector2.ZERO, Vector2(11.0, -7.0), Vector2(-8.0, 6.0)]
	var tints := [Color(0.2, 1.0, 1.0, 0.16), Color(1.0, 0.15, 0.55, 0.11), Color(1.0, 1.0, 1.0, 0.08)]
	for index in range(frame_paths.size()):
		var sky_image := TextureRect.new()
		sky_image.texture = load(frame_paths[index])
		sky_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky_image.stretch_mode = TextureRect.STRETCH_SCALE
		sky_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sky_image.position = offsets[index]
		sky_image.modulate = tints[index]
		sky_layer.add_child(sky_image)


func _create_fake_collision_gap() -> void:
	var floor_candidates: Array[Vector2i] = []
	var fallback_candidates: Array[Vector2i] = []
	var centers_by_cell: Dictionary = {}
	for cell in tile_map_layer.get_used_cells():
		var source_id := tile_map_layer.get_cell_source_id(cell)
		if source_id < 0:
			continue
		var atlas_source := tile_map_layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas_source == null:
			continue
		var atlas_coords := tile_map_layer.get_cell_atlas_coords(cell)
		var alternative := tile_map_layer.get_cell_alternative_tile(cell)
		var tile_data := atlas_source.get_tile_data(atlas_coords, alternative)
		if tile_data == null or tile_data.get_collision_polygons_count(0) == 0:
			continue

		var world_center := tile_map_layer.to_global(tile_map_layer.map_to_local(cell))
		if world_center.x < 0.0 or world_center.x > ORIGINAL_LEVEL_RIGHT_EDGE - TILE_WORLD_SIZE:
			continue
		centers_by_cell[cell] = world_center
		fallback_candidates.append(cell)
		if world_center.y > player.global_position.y + 20.0 and world_center.y < player.global_position.y + 250.0:
			floor_candidates.append(cell)

	var candidates := floor_candidates if not floor_candidates.is_empty() else fallback_candidates
	if candidates.is_empty():
		return

	var bottom_floor_y := -INF
	for cell in candidates:
		bottom_floor_y = maxf(bottom_floor_y, centers_by_cell[cell].y)

	var visual_only_layer := TileMapLayer.new()
	visual_only_layer.name = "VisualOnlyBottomFloor"
	visual_only_layer.tile_set = tile_map_layer.tile_set
	visual_only_layer.collision_enabled = false
	visual_only_layer.transform = tile_map_layer.transform
	add_child(visual_only_layer)
	for cell in candidates:
		var world_center: Vector2 = centers_by_cell[cell]
		if not is_equal_approx(world_center.y, bottom_floor_y):
			continue
		var source_id := tile_map_layer.get_cell_source_id(cell)
		var atlas_coords := tile_map_layer.get_cell_atlas_coords(cell)
		var alternative := tile_map_layer.get_cell_alternative_tile(cell)
		visual_only_layer.set_cell(cell, source_id, atlas_coords, alternative)
		tile_map_layer.erase_cell(cell)
		_fake_floor_gaps.append(Rect2(
			world_center.x - TILE_WORLD_SIZE * 0.5,
			world_center.y - 60.0,
			TILE_WORLD_SIZE,
			120.0
		))


func _build_lower_obstacles() -> void:
	_create_platform(Vector2(330.0, 930.0), Vector2(190.0, 22.0), Color(0.31, 0.24, 0.29))
	_create_platform(Vector2(810.0, 860.0), Vector2(160.0, 22.0), Color(0.21, 0.31, 0.34))
	_create_platform(Vector2(1510.0, 960.0), Vector2(210.0, 22.0), Color(0.31, 0.24, 0.29))
	_create_platform(Vector2(2010.0, 1080.0), Vector2(54.0, 78.0), Color(0.47, 0.22, 0.31))


func _build_lower_level() -> void:
	_create_platform(Vector2(240.0, 1060.0), Vector2(520.0, 32.0), Color(0.18, 0.34, 0.35))
	_create_platform(Vector2(880.0, 1280.0), Vector2(390.0, 28.0), Color(0.28, 0.25, 0.37))
	_create_platform(Vector2(1390.0, 1080.0), Vector2(490.0, 30.0), Color(0.18, 0.34, 0.35))
	_create_platform(Vector2(2010.0, 1330.0), Vector2(500.0, 28.0), Color(0.28, 0.25, 0.37))
	_create_platform(Vector2(2670.0, 1080.0), Vector2(620.0, 30.0), Color(0.18, 0.34, 0.35))
	_create_platform(Vector2(3400.0, 1270.0), Vector2(540.0, 30.0), Color(0.28, 0.25, 0.37))

	for obstacle_x in [450.0, 1050.0, 1650.0, 2250.0, 2850.0, 3450.0]:
		_create_platform(Vector2(obstacle_x, 1745.0), Vector2(72.0, 70.0), Color(0.48, 0.22, 0.29))

	_create_platform(Vector2(1900.0, 1810.0), Vector2(4600.0, 60.0), Color(0.15, 0.22, 0.28))
	for index in range(25):
		var center_x := 120.0 + index * 170.0
		var center_y := 1570.0 + (index % 2) * 40.0
		_create_platform(
			Vector2(center_x, center_y),
			Vector2(200.0, 24.0),
			Color(0.16, 0.38, 0.36),
			true,
			index % 4 == 2
		)


func _create_platform(center: Vector2, size: Vector2, tint: Color, solid: bool = true, moving: bool = false) -> Node2D:
	var platform: Node2D
	if moving:
		var moving_body := AnimatableBody2D.new()
		moving_body.sync_to_physics = true
		platform = moving_body
		_moving_platforms.append({
			"body": moving_body,
			"origin": center,
			"phase": _rng.randf_range(0.0, TAU)
		})
	else:
		platform = StaticBody2D.new()
	platform.position = center
	add_child(platform)

	var visual := Polygon2D.new()
	var half_size := size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
	visual.color = tint
	platform.add_child(visual)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.disabled = not solid
	collision.name = "CollisionShape2D"
	platform.add_child(collision)
	return platform


func _add_status_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	_status_label = Label.new()
	_status_label.position = Vector2(20.0, 16.0)
	_status_label.text = "LIVES: %s   BUILD: STABLE" % player.get("lives")
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(0.83, 0.95, 0.91))
	hud.add_child(_status_label)


func _add_glitch_audio() -> void:
	_ambient_sound = AudioStreamPlayer2D.new()
	_ambient_sound.stream = GLITCH_SOUND
	_ambient_sound.volume_db = -12.0
	add_child(_ambient_sound)


func _add_goal() -> void:
	var goal := Area2D.new()
	goal.name = "Goal"
	goal.position = Vector2(4100.0, 1480.0)
	goal.body_entered.connect(_on_goal_body_entered)
	add_child(goal)

	var goal_shape := CollisionShape2D.new()
	var goal_rectangle := RectangleShape2D.new()
	goal_rectangle.size = Vector2(120.0, 160.0)
	goal_shape.shape = goal_rectangle
	goal.add_child(goal_shape)

	_add_goal_beam(goal, Vector2(-42.0, 0.0), Vector2(14.0, 160.0))
	_add_goal_beam(goal, Vector2(42.0, 0.0), Vector2(14.0, 160.0))
	_add_goal_beam(goal, Vector2(0.0, -73.0), Vector2(98.0, 14.0))

	var goal_label := Label.new()
	goal_label.text = "GOAL"
	goal_label.position = Vector2(-40.0, -118.0)
	goal_label.size = Vector2(80.0, 32.0)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.add_theme_font_size_override("font_size", 22)
	goal_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.78))
	goal.add_child(goal_label)


func _add_goal_beam(goal: Area2D, center: Vector2, size: Vector2) -> void:
	var beam := Polygon2D.new()
	var half_size := size * 0.5
	beam.position = center
	beam.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
	beam.color = Color(0.2, 1.0, 0.72)
	goal.add_child(beam)


func _on_goal_body_entered(body: Node2D) -> void:
	if body != player or _goal_reached:
		return
	_goal_reached = true
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	_show_victory_screen()


func _show_victory_screen() -> void:
	var victory_layer := CanvasLayer.new()
	victory_layer.layer = 30
	add_child(victory_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.035, 0.04, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_layer.add_child(backdrop)

	var victory_title := Label.new()
	victory_title.text = "BUILD ESCAPED"
	victory_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	victory_title.position = Vector2(-260.0, -90.0)
	victory_title.size = Vector2(520.0, 80.0)
	victory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_title.add_theme_font_size_override("font_size", 44)
	victory_title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.78))
	victory_layer.add_child(victory_title)

	var victory_message := Label.new()
	victory_message.text = "YOU REACHED THE END"
	victory_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	victory_message.position = Vector2(-240.0, 5.0)
	victory_message.size = Vector2(480.0, 44.0)
	victory_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_message.add_theme_font_size_override("font_size", 24)
	victory_message.add_theme_color_override("font_color", Color(0.9, 0.96, 0.92))
	victory_layer.add_child(victory_message)

	await get_tree().create_timer(2.0).timeout
	if _goal_reached and not _crash_event_shown:
		_show_fake_crash()


func _show_fake_crash() -> void:
	_crash_event_shown = true
	player.set_physics_process(false)

	var crash_layer := CanvasLayer.new()
	crash_layer.layer = 35
	add_child(crash_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.025, 0.03, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crash_layer.add_child(backdrop)

	var crash_message := Label.new()
	crash_message.text = "FATAL ERROR 0x0000FLOOR\n\nRECOVERING CORRUPTED ASSETS..."
	crash_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crash_message.position = Vector2(-300.0, -90.0)
	crash_message.size = Vector2(600.0, 180.0)
	crash_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crash_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crash_message.add_theme_font_size_override("font_size", 26)
	crash_message.add_theme_color_override("font_color", Color(1.0, 0.36, 0.42))
	crash_layer.add_child(crash_message)

	await get_tree().create_timer(1.6).timeout
	crash_layer.queue_free()
	if not _goal_reached:
		player.set_physics_process(true)