extends CharacterBody2D

@export var move_speed: float = 220.0
@export var jump_force: float = 420.0
@export var gravity: float = 1200.0

var ui_blocked := false

@onready var interact_area: Area2D = $InteractArea
@onready var sprite: AnimatedSprite2D = $Sprite2D

func set_ui_blocked(v: bool) -> void:
	ui_blocked = v

func _physics_process(delta):
	if ui_blocked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# horizontal movement
	var dir := 0
	if Input.is_action_pressed("move_left"):
		dir -= 1
	if Input.is_action_pressed("move_right"):
		dir += 1

	velocity.x = dir * move_speed

	# jump
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jump_force

	move_and_slide()
	_update_animation(dir)

func _input(event):
	if event.is_action_pressed("interact"):
		try_interact()

	if event.is_action_pressed("open_bag"):
		var ui = get_tree().get_first_node_in_group("ui_manager")
		if ui:
			ui.toggle_bag(self)


func try_interact():
	var targets = interact_area.get_overlapping_bodies() + interact_area.get_overlapping_areas()
	for obj in targets:
		if obj.has_method("interact"):
			obj.interact(self)
			return

func _update_animation(dir: int) -> void:
	if not is_on_floor():
		sprite.play("Jump")
	elif dir != 0:
		sprite.play("Walk")
	else:
		sprite.play("Idle")

	if dir != 0:
		sprite.flip_h = dir < 0
