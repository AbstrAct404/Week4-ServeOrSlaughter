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

@onready var cook_status: Label = $CookingPanel/VBoxContainer/StatusLabel
@onready var shop_status: Label = $ShopPanel/VBoxContainer/StatusLabel
@onready var bag_status: Label = $BagPanel/VBoxContainer/StatusLabel
@onready var hotbar_root: Control = $Hotbar
@onready var hotbar_slots := [
	$Hotbar/HBoxContainer/Slot1/Icon,
	$Hotbar/HBoxContainer/Slot2/Icon,
	$Hotbar/HBoxContainer/Slot3/Icon
]
@onready var hotbar_panels := [
	$Hotbar/HBoxContainer/Slot1,
	$Hotbar/HBoxContainer/Slot2,
	$Hotbar/HBoxContainer/Slot3
]


var ui_open := false
var mode := "" # "cook" / "shop"
var selection_index := 0
var current_player: Node = null
var cook_sel := 0
var shop_sel := 0
var bag_sel := 0
var bag_view_ids: Array[String] = []
var ignore_next_interact := false


var recipes := [
	{
		"id": "spicy_wrap",
		"name": "Spicy Wrap",
		"needs": {"flatbread": 1, "pork": 1, "spice": 1},
		"gives": {"meal_spicy_wrap": 1} #changed meat_monster to meat_pork to be able to craft with no monsters
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
	{"id":"pork",     "name":"Pork",          "price": 14},
]

func _item_icon(id: String) -> Texture2D:
	if id == "":
		return null
	match id: ##temp assets
		"veggies":
			return load("res://Assets/Vegetables.png")
		"meat_monster":
			return load("res://Assets/Meat.png")
		"spice":
			return load("res://Assets/Silverware.png")
		"sauce":
			return load("res://Assets/Fruit.png")
		"flatbread":
			return load("res://Assets/Furniture.png")
		_:
			return load("res://Assets/Fruit.png")


func _refresh_hud():
	for i in range(3):
		var id := Inventory.hotbar[i]
		var icon: TextureRect = hotbar_slots[i]
		icon.texture = _item_icon(id)

		var p: PanelContainer = hotbar_panels[i]
		p.modulate = Color(1,1,1,1) if i == Inventory.hotbar_selected else Color(0.7,0.7,0.7,1)


func _ready():
	set_process_unhandled_input(true)
	_build_cooking_ui()
	_build_shop_ui()
	_hide_all()
	add_to_group("ui_manager")
	Inventory.changed.connect(_refresh_hud)
	_refresh_hud()



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
		if ignore_next_interact:
			ignore_next_interact = false
			get_viewport().set_input_as_handled()
			return

		_confirm()
		get_viewport().set_input_as_handled()

		
	if ui_open and mode == "bag" and event.is_action_pressed("swap_hotbar"):
		if selection_index >= 0 and selection_index < bag_view_ids.size():
			var id := bag_view_ids[selection_index]
			var ok := Inventory.equip_from_bag(id)
			if ok:
				_set_status("Equipped to slot %d: %s" % [Inventory.hotbar_selected + 1, id], true)
			else:
				_set_status("Cannot equip.", false)
			_refresh_bag()
			_refresh_hud()



func open_cooking(player: Node) -> void:
	current_player = player
	_lock_player(true)

	mode = "cook"
	ui_open = true
	selection_index = cook_sel

	ignore_next_interact = true

	cooking_panel.visible = true
	shop_panel.visible = false
	_refresh_cooking()


func open_shop(player: Node) -> void:
	current_player = player
	_lock_player(true)

	mode = "shop"
	ui_open = true
	selection_index = shop_sel

	ignore_next_interact = true

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
		cook_sel = selection_index
		_refresh_cooking()
	elif mode == "shop": 
		shop_sel = selection_index
		_refresh_shop()
	elif mode == "bag": 
		bag_sel = selection_index
		_refresh_bag()


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

	_set_status("Cooked: %s" % r["name"], true)
	
	
func _buy_selected():
	var it = shop_items[selection_index]
	var price := int(it["price"])
	print("BUY CALLED item =", it["id"], "price =", price, "money before =", Inventory.money)

	if Inventory.money < price:
		_set_status("Not enough money.", false)
		return

	Inventory.money -= price
	Inventory.add_item(it["id"], 1)
	print("money after =", Inventory.money)
	_set_status("Bought: %s" % it["name"], true)



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
	selection_index = bag_sel

	bag_panel.visible = true
	cooking_panel.visible = false
	shop_panel.visible = false
	_refresh_bag()



#fixed the function so it can refelct real buying action
func _refresh_bag() -> void:
	bag_money.text = "Money: $%d" % Inventory.money
	
	for c in bag_list.get_children():
		c.queue_free()
		
	bag_view_ids.clear()  # <-- move clear HERE
	
	var keys := Inventory.bag.keys()
	keys.sort()
	
	for k in keys:
		var amt := int(Inventory.bag.get(k, 0))
		if amt <= 0:
			continue
		var line := Label.new()
		bag_view_ids.append(k)
		line.text = "%s x%d" % [k, amt]
		bag_list.add_child(line)



func _set_status(msg: String, ok: bool) -> void:
	var c = Color(0.25, 0.9, 0.35) if ok else Color(0.95, 0.25, 0.25)
	if mode == "cook":
		cook_status.text = msg
		cook_status.modulate = c
	elif mode == "shop":
		shop_status.text = msg
		shop_status.modulate = c
	elif mode == "bag":
		bag_status.text = msg
		bag_status.modulate = c
