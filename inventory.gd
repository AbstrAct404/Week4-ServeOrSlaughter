extends Node

var bag: Dictionary = {
	"flatbread": 1,
	"meat_pork": 0,
	"meat_beef": 0,
	"meat_chicken": 0,
	"meat_monster": 0,
	"meat_human": 0,
	"meat_mixed": 0,
	"mushroom": 0,
	"veggies": 2,
	"sauce": 0,
	"spice": 1
}

var money: int = 50

func has_item(id: String, amount: int = 1) -> bool:
	return int(bag.get(id, 0)) >= amount

func add_item(id: String, amount: int = 1) -> void:
	bag[id] = int(bag.get(id, 0)) + amount

func remove_item(id: String, amount: int = 1) -> bool:
	if not has_item(id, amount):
		return false
	bag[id] = int(bag.get(id, 0)) - amount
	return true
