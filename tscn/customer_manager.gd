extends Node
class_name CustomerManager

@export var customer_scene: PackedScene
@export var door_path: NodePath
@export var spawn_pos: Vector2 = Vector2(240, 560)
@export var queue_dir: Vector2 = Vector2(1, 0)

@export var queue_spacing: float = 300.0
@export var inside_min_distance := 70.0  # tweak based on sprite size

@export var max_customers: int = 5
@export var spawn_marker: NodePath
@export var door_outside_marker: NodePath
@export var inside_min_marker: NodePath
@export var inside_max_marker: NodePath
@export var exit_marker: NodePath
@export var max_inside := 4
@export var max_total := 5
@export var player_path: NodePath


# assumed store interior to the RIGHT of door
@export var inside_min: Vector2 = Vector2(660, 505)
@export var inside_max: Vector2 = Vector2(920, 565)

@export var exit_pos: Vector2 = Vector2(180, 560)
@export var exit_radius: float = 18.0

var _toast_stack := 0


var customers: Array = []
var _spawn_timer := 0.0
var _spawn_interval := 6.0
var inside: Array[Customer] = []
var queue: Array[Customer] = []



var _murder_penalty_used := false

func _ready() -> void:
	randomize()
	if customer_scene == null:
		# default
		if ResourceLoader.exists("res://tscn/customer.tscn"):
			customer_scene = load("res://tscn/customer.tscn")

func _process(delta: float) -> void:
	_spawn_timer += delta

	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		_spawn_interval = randf_range(5.0, 9.0)

		if _alive_customer_count() < max_total:
			_spawn_customer()

	_tick_admission()


func _tick_admission() -> void:
	var door = get_door()
	if door == null or not door.is_open:
		_reposition_queue()
		return

	while inside.size() < max_inside and queue.size() > 0:
		var c: Customer = queue.pop_front()
		_send_into_shop(c)

	_reposition_queue()


func _spawn_customer() -> void:
	if customer_scene == null:
		return

	var c := customer_scene.instantiate() as Customer
	add_child(c)
	c.set_manager(self)

	var sp := spawn_pos
	if spawn_marker != NodePath():
		var n = get_node_or_null(spawn_marker)
		if n: sp = n.global_position
	c.global_position = sp

	var r := randi() % 3
	c.race = r
	var cost := 10
	if c.race == 2:
		cost = 6
	else:
		cost = 14
	c.update_payment_profile(cost)

	if inside.size() < max_inside:
		_send_into_shop(c)
	else:
		_enqueue_outside(c)


func _update_queue_targets() -> void:
	for i in range(customers.size()):
		var c = customers[i]
		if c.state == c.State.DEAD:
			continue
		# if not entered yet, keep in queue
		if not c.entered_shop and c.state == c.State.QUEUE:
			var p := spawn_pos + queue_dir.normalized() * queue_spacing * float(i)
			c.set_queue_target(p, i)

	# front-of-line can enter if door open
	if customers.size() > 0:
		var front = customers[0]
		if front.state == front.State.QUEUE:
			var door = get_door()
			if door and door.is_open:
				front.set_inside_target(_random_inside_pos())

func _all_customers() -> Array[Customer]:
	var arr: Array[Customer] = []
	for c in inside:
		if c != null: arr.append(c)
	for c in queue:
		if c != null: arr.append(c)
	return arr


func is_pos_inside(pos: Vector2) -> bool:
	var door = get_door()
	if door == null:
		return false
	# interior assumed to the right of door
	return pos.x > (door.global_position.x + 10.0)

func get_exit_pos() -> Vector2:
	return exit_pos

func is_at_exit(pos: Vector2) -> bool:
	return pos.distance_to(exit_pos) <= exit_radius

func _random_inside_pos() -> Vector2:
	var a = get_node(inside_min_marker).global_position
	var b = get_node(inside_max_marker).global_position
	var minv = Vector2(min(a.x,b.x), min(a.y,b.y))
	var maxv = Vector2(max(a.x,b.x), max(a.y,b.y))

	# try multiple times to find a spot not too close to others
	for _i in range(12):
		var p = Vector2(randf_range(minv.x, maxv.x), randf_range(minv.y, maxv.y))

		var ok := true
		for other in inside:
			if other != null and is_instance_valid(other):
				if other.global_position.distance_to(p) < inside_min_distance:
					ok = false
					break

		if ok:
			return p

	# fallback if crowded
	return Vector2(randf_range(minv.x, maxv.x), randf_range(minv.y, maxv.y))


func get_door():
	if door_path == NodePath():
		# try find Door in scene
		return get_tree().get_first_node_in_group("door") if get_tree() else null
	return get_node_or_null(door_path)

func force_open_door() -> void:
	var door = get_door()
	if door and door.has_method("set_open"):
		door.set_open(true)

func should_wait_before_opening_door(cust) -> bool:
	var door = get_door()
	if door == null:
		return false
	if cust != null and cust.state == cust.State.PANIC:
		return not door.is_open
	return false


# -------- interaction entry --------
func on_customer_interact(cust, player) -> void:
	var ui = get_tree().get_first_node_in_group("ui_manager")
	if ui == null:
		return

	var can_kill := true
	var can_submit := _player_can_satisfy(cust.want_kind)

	var want_text := "Customer wants: %s\nGold now: %d   Rep now: %d" % [
		cust.want_kind.to_upper(),
		cust.calc_gold_now(),
		cust.calc_rep_now()
	]

	ui.open_customer_menu(player, cust, can_submit, can_kill, want_text)

func _player_can_satisfy(kind: String) -> bool:
	# kind is now an exact item id, like "meal_meat_wrap"
	return Inventory.has_item(kind, 1)


func _consume_for_kind(kind: String) -> bool:
	# kind is an exact item id, like "meal_meat_wrap"
	return Inventory.remove_item(kind, 1)


# -------- submit food --------
func on_customer_submit(cust, player) -> void:
	if cust.state == cust.State.DEAD:
		return

	if not _consume_for_kind(cust.want_kind):
		_toast_player(player, "No valid food!")
		return

	# decide payment
	var gold = cust.calc_gold_now()
	var rep_delta = cust.calc_rep_now()

	# if rep < 0, chance to refuse payment and become THIEF
	if Inventory.reputation < 0:
		var p = clamp(-float(Inventory.reputation) / 50.0, 0.0, 1.0) * 0.65
		if randf() < p:
			cust.thief = true
			cust.no_rep_loss_if_killed = true
			_toast_player(player, "Customer refuses to pay!")
			_mark_thief(cust)
			_send_customer_away(cust, false)
			return

	Inventory.add_money(gold)
	Inventory.add_reputation(rep_delta)

	_toast_player(player, "+$%d  Rep %+d" % [gold, rep_delta])

	if Inventory.is_game_over():
		_toast_player(player, "REPUTATION TOO LOW - GAME OVER")
		get_tree().paused = true
		return

	_send_customer_away(cust, false)

# -------- kill customer --------
func on_customer_kill(cust, player) -> void:
	if cust.state == cust.State.DEAD:
		return

	# drops (to backpack)
	var drops: Dictionary = {}

	match cust.race:
		0: # monster
			drops["meat_monster"] = 1
			if randf() < 0.10:
				drops["sauce"] = 1
		1: # human
			drops["meat_human"] = 1
			if randf() < 0.20:
				drops["spice"] = 1
		2: # animal
			# animal drops only its own meat (random for now)
			var choice = ["pork","beef","chicken"][randi()%3]
			drops[choice] = 1

	for k in drops.keys():
		Inventory.add_item(k, int(drops[k]))
		_toast_player(player, "+%s x%d" % [k, int(drops[k])])

	# witness & reputation penalty
	var rep_loss := 0
	if not cust.no_rep_loss_if_killed:
		var should_penalize := _handle_murder_witnesses(cust)
		if should_penalize and not cust.no_rep_loss_if_killed:
			Inventory.add_reputation(-10)
			_toast_player(player, "Witnessed murder! Rep -10")
			if Inventory.is_game_over():
				_toast_player(player, "REPUTATION TOO LOW - GAME OVER")
				get_tree().paused = true


	# remove killed customer
	_remove_customer(cust)
	_tick_admission()


func _handle_murder_witnesses(killed: Customer) -> bool:
	var door = get_door()
	var door_closed = (door != null and not door.is_open)

	var killed_inside := is_pos_inside(killed.global_position)

	var any_visible := false
	var any_calm_visible := false

	var witness_radius := 300.0  # tweak

	for c in _all_customers():
		if c == killed or c.state == c.State.DEAD:
			continue

		# if door is closed, don't see across door sides
		if door_closed and is_pos_inside(c.global_position) != killed_inside:
			continue

		# NEW: only nearby customers witness it
		if c.global_position.distance_to(killed.global_position) > witness_radius:
			continue

		any_visible = true
		if c.state != c.State.PANIC:
			any_calm_visible = true

		c.set_panic()
		c.request_leave()
		c.target_pos = get_exit_pos()

	return any_visible and any_calm_visible


func _mark_thief(cust) -> void:
	# simple visual cue on customer head
	if cust.desire_label:
		cust.desire_label.text = "THIEF\n(no rep loss)"

# -------- leaving & cleanup --------
func _send_customer_away(cust, panic: bool) -> void:
	cust.request_leave()
	cust.state = cust.State.LEAVING if not panic else cust.State.PANIC
	cust.target_pos = get_exit_pos()

func on_customer_left(cust) -> void:
	_remove_customer(cust)
	_tick_admission()
	# reset murder-penalty lock when crowd is calm/empty
	if customers.size() == 0:
		_murder_penalty_used = false

func _remove_customer(cust) -> void:
	var idx := inside.find(cust)
	if idx != -1:
		inside.remove_at(idx)

	idx = queue.find(cust)
	if idx != -1:
		queue.remove_at(idx)

	if is_instance_valid(cust):
		cust.queue_free()
		
	_tick_admission()  


func _toast_player(player, text: String) -> void:
	var ui = get_tree().get_first_node_in_group("ui_manager")
	if ui == null:
		return

	var world := Vector2.ZERO
	if player != null and player is Node2D:
		world = player.global_position

	var screen := get_viewport().get_canvas_transform() * (world + Vector2(0, -32))

	_toast_stack = (_toast_stack + 1) % 6
	screen.y -= 18 * _toast_stack  # NEW: stacks upward

	ui.show_toast(screen, text)



func _queue_slot_pos(i: int) -> Vector2:
	var base := spawn_pos
	if door_outside_marker != NodePath():
		var m := get_node_or_null(door_outside_marker)
		if m and m is Node2D:
			base = (m as Node2D).global_position

	var dir := queue_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(-1, 0)

	return base + dir * queue_spacing * float(i)


func _reposition_queue() -> void:
	for i in range(queue.size()):
		var c: Customer = queue[i]
		if c == null or c.state == c.State.DEAD:
			continue
		c.set_queue_target(_queue_slot_pos(i), i)

func _send_into_shop(c: Customer) -> void:
	inside.append(c)
	c.set_inside_target(_random_inside_pos())

func _on_customer_gone(c: Customer):
	inside.erase(c)
	queue.erase(c)
	_reposition_queue()
	_try_admit_from_queue()

func _try_admit_from_queue():
	while inside.size() < max_inside and queue.size() > 0:
		var c = queue.pop_front()
		_send_into_shop(c)
	_reposition_queue()

func _enqueue_outside(c: Customer) -> void:
	queue.append(c)
	c.state = c.State.QUEUE
	_reposition_queue()
	
func on_customer_patience_expired(cust) -> void:
	if cust == null:
		return
	# If already leaving/dead, ignore
	if cust.state == cust.State.DEAD:
		return

	Inventory.add_reputation(-4)
	_toast_player(get_player(), "Rep -4 (impatient customer)")

	# send away normally; door-closed logic (wait 3s) should be inside _send_customer_away
	_send_customer_away(cust, false)

func get_player() -> Node2D:
	var p = get_node_or_null(player_path)
	if p != null and p is Node2D:
		return p
	return null


func _alive_customer_count() -> int:
	var count := 0
	for c in _all_customers():
		if is_instance_valid(c) and c.state != c.State.DEAD:
			count += 1
	return count
