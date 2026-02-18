extends Area2D
class_name Customer

enum Race { MONSTER, HUMAN, ANIMAL }
enum State { QUEUE, ENTERING, WAITING, LEAVING, PANIC, DEAD }

@export var race: Race = Race.HUMAN
@export var patience_max: float = 20.0

var patience_left: float = 0.0
var patience_running: bool = false

@onready var patience_bar: ProgressBar = $"Patience"

# For now:
# - Monster/Human want any meat
# - Animal wants veggies
var want_kind: String = "meat" # "meat" / "veggie"

var state: State = State.QUEUE
var manager: Node = null

var queue_index: int = 0
var target_pos: Vector2 = Vector2.ZERO

var entered_shop := false
var entered_at: float = 0.0

# payment model
var material_cost: int = 10
var a_mult: float = 1.5
var max_gold: int = 15

var thief := false
var no_rep_loss_if_killed := false # used for THIEF cases

var _leave_requested := false
var _leave_wait := 0.0

@onready var desire_label: Label = $DesireLabel
@onready var sprite: Sprite2D = $Sprite2D

const WANT_POOL := [
	"meal_meat_wrap",
	"meal_veggie_wrap",
	"meal_mushroom_soup",
	"meal_chicken_skewers"
]

const WANT_NAMES := {
	"meal_meat_wrap": "Meat Wrap",
	"meal_veggie_wrap": "Veggie Wrap",
	"meal_mushroom_soup": "Mushroom Soup",
	"meal_chicken_skewers": "Chicken Skewers"
}

func _ready() -> void:
	collision_layer = 4
	_pick_want()
	_refresh_visual()
	if patience_bar:
		patience_bar.visible = false
		patience_bar.min_value = 0.0
		patience_bar.max_value = 1.0
		patience_bar.value = 1.0


func _pick_want() -> void:
	want_kind = WANT_POOL.pick_random()


func _refresh_visual() -> void:
	match race:
		Race.MONSTER:
			sprite.texture = load("res://Assets/monster.png")
			sprite.scale = Vector2(3, 3)  # try 3 first
		Race.HUMAN:
			sprite.texture = load("res://Assets/monster.png")
			sprite.scale = Vector2(1.5,1.5)
		Race.ANIMAL:
			sprite.texture = load("res://Assets/monster.png")
			sprite.scale = Vector2(3, 3)
		_:
			pass

	sprite.centered = true
	sprite.offset = Vector2(0, -16)  # lift slightly so feet touch ground

	var name: String = str(WANT_NAMES.get(want_kind, want_kind))
	desire_label.text = "WANT:\n%s" % name
	desire_label.position = Vector2(0, -80)



func set_manager(m: Node) -> void:
	manager = m

func set_queue_target(p: Vector2, idx: int) -> void:
	queue_index = idx
	target_pos = p

func set_inside_target(p: Vector2) -> void:
	target_pos = p
	state = State.ENTERING

func set_waiting() -> void:
	state = State.WAITING
	entered_shop = true
	entered_at = Time.get_ticks_msec() / 1000.0
	_leave_requested = false
	_leave_wait = 0.0

func set_panic() -> void:
	if state == State.DEAD:
		return
	state = State.PANIC
	_leave_requested = true
	_leave_wait = 0.0
	_stop_patience()
	if desire_label:
		desire_label.text = "PANIC!"

func request_leave() -> void:
	_leave_requested = true

func is_inside_shop() -> bool:
	if manager and manager.has_method("is_pos_inside"):
		return manager.is_pos_inside(global_position)
	return false

func get_elapsed_in_shop() -> float:
	if not entered_shop:
		return 0.0
	var now := Time.get_ticks_msec() / 1000.0
	return max(0.0, now - entered_at)

func calc_gold_now() -> int:
	var t = clamp(get_elapsed_in_shop() / 30.0, 0.0, 1.0)
	var gold := int(round(lerp(float(max_gold), 0.0, t)))
	if entered_shop and get_elapsed_in_shop() >= 30.0:
		gold = 0
	# rep bonus to gold
	var rep := Inventory.reputation
	var bonus = 1.0 + 0.5 * clamp(float(rep) / 50.0, 0.0, 1.0)
	return int(round(float(gold) * bonus))

func calc_rep_now() -> int:
	# +3 down to -4 over 30 seconds
	var t = clamp(get_elapsed_in_shop() / 30.0, 0.0, 1.0)
	var repf = lerp(3.0, -4.0, t)
	return int(round(repf))

func update_payment_profile(cost: int) -> void:
	material_cost = cost
	a_mult = randf_range(1.4, 1.6)
	max_gold = int(round(float(material_cost) * a_mult))

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	# movement (simple kinematic)
	var speed := 90.0
	if state == State.PANIC:
		speed = 140.0

	if state in [State.QUEUE, State.ENTERING, State.LEAVING, State.PANIC]:
		var to := target_pos - global_position
		
		var dist := to.length()
		if dist > 2.0:
			var step: float = min(speed * delta, dist)
			global_position += (to / dist) * step

	
	# waiting logic
	if state == State.WAITING:
		if global_position.distance_to(target_pos) <= 2.0:
			state = State.WAITING
			_start_patience()
		# after 30s -> leave
		if get_elapsed_in_shop() >= 30.0:
			_leave_requested = true

		if _leave_requested:
			state = State.LEAVING
			if manager and manager.has_method("get_exit_pos"):
				target_pos = manager.get_exit_pos()

	# leaving logic
	if state in [State.LEAVING, State.PANIC]:
		if manager and manager.has_method("should_wait_before_opening_door"):
			if manager.should_wait_before_opening_door(self):
				_leave_wait += delta
				if _leave_wait >= 3.0:
					manager.force_open_door()
				else:
					# hold position while waiting
					return

		# reached exit -> despawn
		if manager and manager.has_method("is_at_exit"):
			if manager.is_at_exit(global_position):
				manager.on_customer_left(self)
				
	if patience_running:
		patience_left -= delta
		var t = clamp(patience_left / patience_max, 0.0, 1.0)
		if patience_bar:
			patience_bar.value = t

		if patience_left <= 0.0:
			patience_left = 0.0
			patience_running = false
			if patience_bar:
				patience_bar.value = 0.0
			# notify manager once
			if manager != null:
				manager.on_customer_patience_expired(self)

func interact(player: Node) -> void:
	if manager and manager.has_method("on_customer_interact"):
		manager.on_customer_interact(self, player)

# ---- callbacks from UI menu ----
func on_player_submit(player: Node) -> void:
	if manager and manager.has_method("on_customer_submit"):
		manager.on_customer_submit(self, player)
	_stop_patience()

func on_player_kill(player: Node) -> void:
	if manager and manager.has_method("on_customer_kill"):
		manager.on_customer_kill(self, player)
	_stop_patience()

func mark_dead() -> void:
	state = State.DEAD
	_stop_patience()
	queue_free()

func _start_patience() -> void:
	patience_left = patience_max
	patience_running = true
	if patience_bar:
		patience_bar.visible = true
		patience_bar.value = 1.0

func _stop_patience() -> void:
	patience_running = false
	if patience_bar:
		patience_bar.visible = false
