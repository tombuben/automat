class_name ShootingHands extends Node3D
## The automat's hands in the world view. They sit behind the held item and
## react to dragging, catching, charging and throwing.
## Place them by moving the Left and Right sprites: that placement is how the
## hands look while holding an item, and every value below is relative to it.

enum Pose { IDLE, REACH, READY, HOLD }

@export_group("Height")
@export var idle_offset := -0.06
@export var reach_offset := 0.02

@export_group("Spread")
@export var reach_spread := 0.04

@export_group("Feel")
@export var pose_time := 0.6
@export var ready_brightness := 1.08
## How much the spread leans the hands outwards, in radians per unit.
@export var lean := 0.2
@export var charge_sink := 0.05
@export var charge_tremble := 0.003
@export var catch_dip := 0.03
@export var throw_thrust := 0.1
## The item is closer to the camera than the hands, so it moves less for the same look.
@export var item_follow := 0.56
## How far above the spawn point the held item rests.
@export var item_rest_height := 0.2

@onready var world_view : WorldView = get_parent()
@onready var left_hand : Sprite3D = $Left
@onready var right_hand : Sprite3D = $Right
@onready var left_base : Transform3D = left_hand.transform
@onready var right_base : Transform3D = right_hand.transform

var pose := Pose.IDLE
var height := idle_offset
var spread := 0.0
var brightness := 1.0
var punch := 0.0

var pose_tween : Tween
var punch_tween : Tween


func _process(_delta : float) -> void:
	_update_pose()

	var charge := world_view.charge_duration / world_view.max_charge_duration if world_view.charging else 0.0
	var tremble := randf_range(-1.0, 1.0) * charge_tremble * charge
	var y := height - charge * charge_sink - punch

	_place_hand(left_hand, left_base, -1.0, y, tremble, charge)
	_place_hand(right_hand, right_base, 1.0, y, -tremble, charge)


## Where the held item should sit so that it moves together with the hands.
func get_item_offset() -> float:
	return item_rest_height + (left_hand.position.y - left_base.origin.y) * item_follow


func catch_item() -> void:
	_start_punch()
	punch_tween.tween_property(self, "punch", catch_dip, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	punch_tween.tween_property(self, "punch", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func throw_item(charge : float) -> void:
	_start_punch()
	punch_tween.tween_property(self, "punch", -throw_thrust * (0.6 + 0.4 * charge), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	punch_tween.tween_property(self, "punch", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_punch() -> void:
	if punch_tween:
		punch_tween.kill()
	punch_tween = create_tween()


func _place_hand(hand : Sprite3D, base : Transform3D, side : float, y : float, tremble : float, charge : float) -> void:
	var x := spread - charge * 0.05
	hand.transform = base
	hand.position += Vector3(side * x + tremble, y, 0.0)
	hand.rotation.z += side * x * lean
	# Squashes on a catch, stretches on a throw.
	hand.scale *= Vector3(1.0 + punch * 0.5, 1.0 - punch * 0.5, 1.0)
	hand.modulate = Color(brightness, brightness, brightness)


func _update_pose() -> void:
	var new_pose := _get_wanted_pose()
	if new_pose == pose:
		return
	pose = new_pose

	var target_height := 0.0
	var target_spread := 0.0
	match pose:
		Pose.IDLE:
			target_height = idle_offset
		Pose.REACH, Pose.READY:
			target_height = reach_offset
			target_spread = reach_spread

	if pose_tween:
		pose_tween.kill()
	pose_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pose_tween.tween_property(self, "height", target_height, pose_time)
	pose_tween.tween_property(self, "spread", target_spread, pose_time)
	pose_tween.tween_property(self, "brightness", ready_brightness if pose == Pose.READY else 1.0, pose_time)


func _get_wanted_pose() -> Pose:
	var cursor := GlobalManager.cursor_body
	if world_view.object_to_shoot:
		return Pose.HOLD
	if cursor and cursor.dragging:
		return Pose.READY if world_view.get_mouse_in_view() != null else Pose.REACH
	return Pose.IDLE
