extends Node

# -----------------------------
# SCENES
# -----------------------------
var scenes: Array = [
	"res://Scenes/main_scene0.tscn",
	"res://Scenes/SnailScenes/SnailScene1.tscn",
	"res://Scenes/main_scene1.tscn",
	"res://Scenes/main_scene2.tscn",
]

func load_into_scene(index: int):
	if index < 0 or index >= scenes.size():
		push_error("Invalid scene index: " + str(index))
		return

	load_scene(scenes[index])

func load_scene(scene_path: String):
	if not ResourceLoader.exists(scene_path):
		push_error("Scene does not exist: " + scene_path)
		return

	print("loading into " + scene_path)
	get_tree().change_scene_to_file(scene_path)

# -----------------------------
# CHARACTERS
# -----------------------------
var characters: Dictionary = {}

# -----------------------------
# CHARACTER STATES
# -----------------------------
var character_states: Dictionary = {}

func get_state(character_name: String, key: String, default_value = null):
	if not character_states.has(character_name):
		character_states[character_name] = {}

	return character_states[character_name].get(key, default_value)

func set_state(character_name: String, key: String, value):
	if not character_states.has(character_name):
		character_states[character_name] = {}

	character_states[character_name][key] = value

func has_state(character_name: String, key: String) -> bool:
	return character_states.has(character_name) and character_states[character_name].has(key)

# -----------------------------
# CHARACTER DATA
# -----------------------------
const CHARACTER_DATA_FOLDER := "res://Characters/"

var _character_data: Dictionary[String, CharacterData] = {}
var _character_data_loaded := false
var _unknown_speakers: Dictionary[String, bool] = {}

func get_character_data(character_id: String) -> CharacterData:
	if not _character_data_loaded:
		_character_data_loaded = true
		for file_name in ResourceLoader.list_directory(CHARACTER_DATA_FOLDER):
			var data := load(CHARACTER_DATA_FOLDER + file_name) as CharacterData
			if data:
				_character_data[data.id] = data

	if character_id != "" and not _character_data.has(character_id) and not _unknown_speakers.has(character_id):
		_unknown_speakers[character_id] = true
		push_warning("No CharacterData for speaker '%s': using the old voice setup" % character_id)

	return _character_data.get(character_id)

# -----------------------------
# SCREEN SHAKE
# -----------------------------
# Shakes the whole window (both views, borders, overlays). CanvasLayers like the
# dialogue balloon and the unlock popups stay still, so text stays readable.

## Zooms in just enough while shaking that the window edges never show.
## The zoom follows the shake's strength and tilt, so a small shake barely zooms.
var screen_shake_zoom_to_cover := true

var _shake_strength := 0.0
var _shake_roll := 0.0
var _shake_duration := 0.0
var _shake_timer := 0.0
var _shake_frequency := 30.0
var _shake_time := 0.0
var _shake_noise := FastNoiseLite.new()
var _shake_last_usec := 0
var _shake_active := false

## intensity: how far the screen moves, in pixels (of the 1920x1080 layout).
## duration: real seconds, keeps going through hitstop. frequency: wiggles per second.
## roll: how far the screen tilts, in degrees.
## A weaker shake won't cut off a stronger one that's still going.
func screen_shake(intensity: float = 12.0, duration: float = 0.2, frequency: float = 30.0, roll: float = 0.0) -> void:
	if duration <= 0.0 or (intensity <= 0.0 and roll <= 0.0):
		return
	var fade := _shake_fade()
	if intensity < _shake_strength * fade and roll < _shake_roll * fade:
		return
	_shake_strength = maxf(intensity, 0.0)
	_shake_roll = maxf(roll, 0.0)
	_shake_duration = duration
	_shake_timer = duration
	_shake_frequency = frequency
	_shake_noise.seed = randi()
	_shake_active = true

## 1 at the start of the shake, 0 when it's over.
func _shake_fade() -> float:
	if _shake_timer <= 0.0:
		return 0.0
	var progress := 1.0 - _shake_timer / _shake_duration
	# Stays strong for most of the shake, then drops off at the end.
	return 1.0 - progress * progress

func _shake_noise_at(t: float, lane: float) -> float:
	# Raw noise mostly sits well inside -1..1, so boost it and clamp.
	return clampf(_shake_noise.get_noise_2d(t, lane) * 2.5, -1.0, 1.0)

func _update_screen_shake() -> void:
	# Real time, so the shake keeps moving while a hitstop slows the game.
	var now := Time.get_ticks_usec()
	var delta := 0.0 if _shake_last_usec == 0 else minf((now - _shake_last_usec) / 1000000.0, 0.1)
	_shake_last_usec = now
	if not _shake_active:
		return

	var root := get_tree().root
	_shake_timer = maxf(_shake_timer - delta, 0.0)
	if _shake_timer <= 0.0:
		_shake_active = false
		root.canvas_transform = Transform2D.IDENTITY
		return

	_shake_time += delta
	var fade := _shake_fade()
	var strength := _shake_strength * fade
	var max_angle := deg_to_rad(_shake_roll) * fade
	var t := _shake_time * _shake_frequency
	var offset := Vector2(_shake_noise_at(t, 0.0), _shake_noise_at(t, 100.0)) * strength
	var angle := _shake_noise_at(t, 200.0) * max_angle

	# Zoom for the biggest move and tilt this moment can have, not this frame's,
	# so the zoom fades out smoothly instead of pumping with every jitter.
	var size := root.get_visible_rect().size
	var zoom := 1.0
	if screen_shake_zoom_to_cover:
		var short_side := minf(size.x, size.y)
		var long_side := maxf(size.x, size.y)
		zoom = cos(max_angle) + (long_side / short_side) * sin(max_angle) \
			+ 2.0 * strength / short_side

	# Rotate and zoom around the screen center, then move.
	var center := size * 0.5
	root.canvas_transform = Transform2D(angle, Vector2(zoom, zoom), 0.0, center + offset) \
		* Transform2D(0.0, -center)

# -----------------------------
# HITSTOP
# -----------------------------
var _hitstop_end_ms := 0
var _hitstop_running := false
var _time_scale_before_hitstop := 1.0

## Slows the whole game for a moment. duration is in real seconds (one frame is
## about 0.016), time_scale 0 is a full freeze. Hits that overlap extend the
## hitstop instead of stacking, and time always comes back to normal.
func hitstop(duration: float, time_scale: float = 0.0) -> void:
	if duration <= 0.0 or time_scale >= 1.0:
		return

	_hitstop_end_ms = maxi(_hitstop_end_ms, Time.get_ticks_msec() + int(duration * 1000.0))
	if not _hitstop_running:
		_time_scale_before_hitstop = Engine.time_scale
	Engine.time_scale = minf(Engine.time_scale, maxf(time_scale, 0.0))

	if _hitstop_running:
		return
	_hitstop_running = true
	while Time.get_ticks_msec() < _hitstop_end_ms:
		await get_tree().process_frame
	Engine.time_scale = _time_scale_before_hitstop
	_hitstop_running = false

# -----------------------------
# DIALOGUE AUDIO BEEPS
# -----------------------------
var GenericCharacterSounds001 = preload("res://Assets/Audio/SpeakingSFX/GenericCharacterSounds001.wav")
var GenericCharacterSounds002 = preload("res://Assets/Audio/SpeakingSFX/GenericCharacterSounds002.wav")
var GenericCharacterSounds003 = preload("res://Assets/Audio/SpeakingSFX/GenericCharacterSounds003.wav")
var GenericCharacterSounds004 = preload("res://Assets/Audio/SpeakingSFX/new/automatVoice1.wav")
var GenericCharacterSounds005 = preload("res://Assets/Audio/SpeakingSFX/new/angryWorker.wav")
var GenericCharacterSounds006 = preload("res://Assets/Audio/SpeakingSFX/new/smallWorkerVoice2.wav")
var GenericCharacterSounds007 = preload("res://Assets/Audio/SpeakingSFX/new/printerVoice1.wav")
var GenericCharacterSounds008 = preload("res://Assets/Audio/SpeakingSFX/new/SadWorkerVoice.wav")
var GenericCharacterSounds009 = preload("res://Assets/Audio/SpeakingSFX/new/smallWorkerVoice.wav")
var GenericCharacterSounds010 = preload("res://Assets/Audio/SpeakingSFX/new/mouseVoice.wav")
var GenericCharacterSounds011 = preload("res://Assets/Audio/SpeakingSFX/new/crowVoices1.wav")
var GenericCharacterSounds012 = preload("res://Assets/Audio/SpeakingSFX/new/crowVoices2.wav")
var GenericCharacterSounds013 = preload("res://Assets/Audio/SpeakingSFX/new/SIVoice.wav")


var character_beeps: Dictionary[String, Array] = {
	"default": [GenericCharacterSounds004],
	"DisposableWorker": [GenericCharacterSounds006],
	"smallWorker": [GenericCharacterSounds009],
	"SadWorker": [GenericCharacterSounds008],
	"printer": [GenericCharacterSounds007],
	"angryWorker": [GenericCharacterSounds005],
	"crow": [GenericCharacterSounds011, GenericCharacterSounds012],
	"mouse": [GenericCharacterSounds010],
	"SI": [GenericCharacterSounds013],
}

signal update_audio_beeps(beep_array: Array[AudioStream])

func set_audio_beeps(speaker_name: String):
	var beeps: Array[AudioStream] = []
	beeps.assign(character_beeps.get(speaker_name, null))
	update_audio_beeps.emit(beeps)

# -----------------------------
# EXISTING SYSTEMS
# -----------------------------
var cursor_body: CursorBody
var drag_ghost: DragGhost
var world_view: WorldView
var rotate_around: RotateAround

var scene_dialogue_manager: SceneDialogueManager
var dialogue_preview: DialoguePreview

# -----------------------------
# SIGNALS
# -----------------------------
signal play_animation(animation_name: String)
var current_animation_length: float

signal person_shoot_selection_started(person_name: String)
var item_that_hit: RandomItem

signal recieve_item(item: String)

# -----------------------------
# ITEM MANAGEMENT
# -----------------------------
var slots: Dictionary[String, ItemSlot] # TODO should clear when level changes

func change_slot_item_name(slot_node_name: String, new_item_name: String):
	if slot_node_name in slots:
		slots[slot_node_name].change_item_name(new_item_name)
	else:
		print("Unknown slot " + slot_node_name + " can't change name to " + new_item_name)

func change_slot_item_saying(slot_node_name: String, new_saying: String):
	if slot_node_name in slots:
		slots[slot_node_name].change_item_saying(new_saying)
	else:
		print("Unknown slot " + slot_node_name + " can't change saying to " + new_saying)

func set_item_preview(item_name: String, preview: String):
	for slot in slots.values():
		if is_instance_valid(slot) and slot.item_backup.item_name == item_name:
			slot.change_item_saying(preview)

# -----------------------------
# LIFECYCLE
# -----------------------------
func _ready() -> void:
	_shake_noise.frequency = 1.0
	_shake_noise.fractal_type = FastNoiseLite.FRACTAL_NONE

func _process(_delta: float) -> void:
	_update_screen_shake()

# -----------------------------
# GLOBAL INPUT
# -----------------------------
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
