extends CanvasLayer

@onready var bag_panel: Control = $BagPanel
@onready var bag_money: Label = $BagPanel/VBoxContainer/MoneyLabel
@onready var bag_list: VBoxContainer = $BagPanel/VBoxContainer/ItemList

@onready var cooking_panel: Control = $CookingPanel
@onready var shop_panel: Control = $ShopPanel
@onready var cook_money: Label = $CookingPanel/VBoxContainer/MoneyLabel
@onready var shop_money: Label = $ShopPanel/VBoxContainer/MoneyLabel

@onready var recipe_list: VBoxContainer = $CookingPanel/VBoxContainer/RecipeList
@onready var recipe_detail: VBoxContainer = $CookingPanel/VBoxContainer/Detail

@onready var shop_list: VBoxContainer = $ShopPanel/VBoxContainer/ItemList

var ui_open := false
var mode := "" # "cook" / "shop"
var selection_index := 0
var current_player: Node = null

var recipes := [
	{
		"id": "spicy_wrap",
		"name": "Spicy Wrap",
		"needs": {"flatbread": 1, "meat_monster": 1, "spice": 1},
		"gives": {"meal_spicy_wrap": 1}
	},
	{
		"id": "veggie_wrap",
		"name": "Veggie Wrap",
		"needs": {"flatbread": 1, "veggies": 2, "sauce": 1},
		"gives": {"meal_veggie_wrap": 1}
	}
]

var shop_items := [
	{"id":"flatbread",     "name":"Flatbread",     "price": 5},
	{"id":"veggies",       "name":"Veggies",       "price": 6},
	{"id":"sauce",         "name":"Sauce",         "price": 7},
	{"id":"spice",         "name":"Spice",         "price": 4},
	{"id":"meat_pork",     "name":"Pork",          "price": 14},
]

func _ready():
	_build_cooking_ui()
	_build_shop_ui()
	_hide_all()

func _unhandled_input(event):
	if not ui_open:
		return

	if event.is_action_pressed("cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_move_selection(1)
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("interact"):
		_confirm()
		get_viewport().set_input_as_handled()


func open_cooking(player: Node) -> void:
	current_player = player
	_lock_player(true)

	mode = "cook"
	ui_open = true
	selection_index = 0

	cooking_panel.visible = true
	shop_panel.visible = false
	_refresh_cooking()

func open_shop(player: Node) -> void:
	current_player = player
	_lock_player(true)

	mode = "shop"
	ui_open = true
	selection_index = 0

	shop_panel.visible = true
	cooking_panel.visible = false
	_refresh_shop()

func close_ui() -> void:
	ui_open = false
	mode = ""
	_hide_all()
	_lock_player(false)
	current_player = null

# ---------- internal ----------
func _lock_player(v: bool) -> void:
	if current_player != null and current_player.has_method("set_ui_blocked"):
		current_player.set_ui_blocked(v)

func _hide_all():
	cooking_panel.visible = false
	shop_panel.visible = false
	bag_panel.visible = false


func _current_count() -> int:
	if mode == "cook":
		return recipe_list.get_child_count()
	if mode == "shop":
		return shop_list.get_child_count()
	return 0

func _move_selection(delta: int):
	var count := _current_count()
	if count <= 0:
		return
	selection_index = clamp(selection_index + delta, 0, count - 1)
	if mode == "cook":
		_refresh_cooking()
	else:
		_refresh_shop()

func _confirm():
	if mode == "cook":
		_cook_selected()
		_refresh_cooking()
	elif mode == "shop":
		_buy_selected()
		_refresh_shop()



func _build_cooking_ui():
	for c in recipe_list.get_children():
		c.queue_free()

	for r in recipes:
		var b := Button.new()
		b.text = r["name"]
		b.focus_mode = Control.FOCUS_NONE
		recipe_list.add_child(b)

	$CookingPanel/VBoxContainer/Title.text = "Cooking"
	$CookingPanel/VBoxContainer/Hint.text = "Arrows: Select   E: Craft   Q: Exit"

func _build_shop_ui():
	for c in shop_list.get_children():
		c.queue_free()

	for it in shop_items:
		var b := Button.new()
		b.text = "%s ($%d)" % [it["name"], int(it["price"])]
		b.focus_mode = Control.FOCUS_NONE
		shop_list.add_child(b)

	$ShopPanel/VBoxContainer/Title.text = "Shop"
	$ShopPanel/VBoxContainer/Hint.text = "Arrows: Select   E: Buy   Q: Exit"

# ---------- refresh visuals ----------
func _refresh_cooking():
	cook_money.text = "Money: $%d" % Inventory.money
	# highlight selection
	for i in recipe_list.get_child_count():
		var b: Button = recipe_list.get_child(i)
		b.modulate = Color(1,1,1,1) if i == selection_index else Color(0.8,0.8,0.8,1)

	# detail: needs (missing -> grey)
	for c in recipe_detail.get_children():
		c.queue_free()

	var r = recipes[selection_index]

	var header := Label.new()
	header.text = "Needs:"
	recipe_detail.add_child(header)

	for k in r["needs"].keys():
		var need_amt := int(r["needs"][k])
		var have_amt := int(Inventory.bag.get(k, 0))
		var ok := Inventory.has_item(k, need_amt)

		var line := Label.new()
		line.text = "- %s x%d (you: %d)" % [k, need_amt, have_amt]
		line.modulate = Color(1,1,1,1) if ok else Color(0.45,0.45,0.45,1)
		recipe_detail.add_child(line)

func _refresh_shop():
	shop_money.text = "Money: $%d" % Inventory.money
	for i in shop_list.get_child_count():
		var b: Button = shop_list.get_child(i)
		b.modulate = Color(1,1,1,1) if i == selection_index else Color(0.8,0.8,0.8,1)

# ---------- actions ----------
func _cook_selected():
	var r = recipes[selection_index]

	# check
	for k in r["needs"].keys():
		var amt := int(r["needs"][k])
		if not Inventory.has_item(k, amt):
			return

	# consume
	for k in r["needs"].keys():
		Inventory.remove_item(k, int(r["needs"][k]))

	# produce
	for k in r["gives"].keys():
		Inventory.add_item(k, int(r["gives"][k]))

func _buy_selected():
	var it = shop_items[selection_index]
	var price := int(it["price"])
	if Inventory.money < price:
		return
	Inventory.money -= price
	Inventory.add_item(it["id"], 1)

func toggle_bag(player: Node) -> void:
	if ui_open and mode == "bag":
		close_ui()
		return

	open_bag(player)

func open_bag(player: Node) -> void:
	current_player = player
	_lock_player(true)

	mode = "bag"
	ui_open = true
	selection_index = 0

	bag_panel.visible = true
	cooking_panel.visible = false
	shop_panel.visible = false
	_refresh_bag()

func _refresh_bag() -> void:
	bag_money.text = "Money: $%d" % Inventory.money

	for c in bag_list.get_children():
		c.queue_free()

	var keys := Inventory.bag.keys()
	keys.sort()

	for k in keys:
		var amt := int(Inventory.bag.get(k, 0))
		if amt <= 0:
			continue
		var line := Label.new()
		line.text = "%s x%d" % [k, amt]
		bag_list.add_child(line)
