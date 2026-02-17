extends Node
signal changed

var bag: Dictionary = {
	"flatbread": 1,
	"pork": 0,
	"beef": 0,
	"chicken": 0,
	"meat_monster": 0,
	"meat_human": 0,
	"meat_mixed": 0,
	"mushroom": 0,
	"veggies": 2,
	"sauce": 0,
	"spice": 1,
	"knife": 1
}

var money: int = 50
var reputation: int = 0
var hotbar: Array[String] = ["", "", ""]
var hotbar_selected: int = 0  # 0..2

func has_item(id: String, amount: int = 1) -> bool:
	return int(bag.get(id, 0)) >= amount

func add_item(id: String, amount: int = 1) -> void:
	bag[id] = int(bag.get(id, 0)) + amount
	emit_signal("changed")

func remove_item(id: String, amount: int = 1) -> bool:
	if not has_item(id, amount):
		return false
	bag[id] = int(bag.get(id, 0)) - amount
	emit_signal("changed")
	return true

func set_selected_slot(slot_index: int) -> void:
	hotbar_selected = clamp(slot_index, 0, 2)
	emit_signal("changed")

func get_selected_item_id() -> String:
	return hotbar[hotbar_selected]

func equip_from_bag(item_id: String) -> bool:
	if item_id == "":
		return false
	if not has_item(item_id, 1):
		return false

	var slot := hotbar_selected
	var old := hotbar[slot]

	remove_item(item_id, 1)
	hotbar[slot] = item_id

	if old != "":
		add_item(old, 1)

	emit_signal("changed")
	return true

func unequip_to_bag() -> bool:
	var slot := hotbar_selected
	var cur := hotbar[slot]
	if cur == "":
		return false
	hotbar[slot] = ""
	add_item(cur, 1)
	emit_signal("changed")
	return true


func add_money(amount: int) -> void:
	money += amount
	emit_signal("changed")

func add_reputation(delta: int) -> void:
	reputation = clamp(reputation + delta, -50, 50)
	emit_signal("changed")

func is_game_over() -> bool:
	return reputation <= -50
