extends CanvasLayer


@onready var coin_label: Label = $HUD/VBox/CoinLabel
@onready var rep_bar: ProgressBar = $HUD/VBox/HBox/RepBar
@onready var rep_text: Label = $HUD/VBox/HBox/RepText



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
		"id": "meat_wrap",
		"name": "Meat Wrap",
		"needs": {"flatbread": 1, "meat": 1, "spice": 1},
		"gives": {"meal_meat_wrap": 1}
	},
	{
		"id": "veggie_wrap",
		"name": "Veggie Wrap",
		"needs": {"flatbread": 1, "veggies": 2, "sauce": 1},
		"gives": {"meal_veggie_wrap": 1}
	},
	
	{
	"id": "mushroom_soup",
	"name": "Mushroom Soup",
	"needs": {"mushroom": 2, "sauce": 1},
	"gives": {"meal_mushroom_soup": 1}
	},
	
	
	{
	"id": "chicken_skewers",
	"name": "Garlic Chicken Skewers",
	"needs": {"chicken": 1, "spice": 1},
	"gives": {"meal_chicken_skewers": 1}
	}
]

var shop_items := [
	{"id":"flatbread",     "name":"Flatbread",     "price": 5},
	{"id":"veggies",       "name":"Veggies",       "price": 6},
	{"id":"sauce",         "name":"Sauce",         "price": 7},
	{"id":"spice",         "name":"Spice",         "price": 4},
	{"id":"pork",     "name":"Pork",          "price": 14},
	{"id":"mushroom",  "name":"Mushroom",  "price": 8},
	{"id":"chicken",   "name":"Chicken",   "price": 14}
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
		"knife":
			return load("res://Assets/Silverware.png")
		"meal_meat_wrap":
			return load("res://Assets/meat_wrap.png") 
		"meal_veggie_wrap":
			return load("res://Assets/veggie_wrap.png") 
		"knife":
			return load("res://Assets/Silverware.png")
		"mushroom":
			return load("res://Assets/Vegetables.png") # temp
		"chicken":
			return load("res://Assets/Meat.png") # temp
		"meal_mushroom_soup":
			return load("res://Assets/mushroom_soup.png") # temp until you draw it
		"meal_chicken_skewers":
			return load("res://Assets/chicken_skewers.png") # temp
			
		_:
			return load("res://Assets/Fruit.png")


func _refresh_hud():
	for i in range(3):
		var id := Inventory.hotbar[i]
		var icon: TextureRect = hotbar_slots[i]
		icon.texture = _item_icon(id)

		var p: PanelContainer = hotbar_panels[i]
		p.modulate = Color(1,1,1,1) if i == Inventory.hotbar_selected else Color(0.7,0.7,0.7,1)
		
		
	# Coins
	coin_label.text = "Coins: $%d" % Inventory.money

	var rep := Inventory.reputation
	var norm := rep + 50

	rep_bar.min_value = 0
	rep_bar.max_value = 100
	rep_bar.value = norm

	rep_text.text = "Respect: %d" % rep


	$HUD/VBox/HBox/RepText.text = "Respect: %d" % Inventory.reputation



func _ready():

	_build_cooking_ui()
	_build_shop_ui()
	_hide_all()
	add_to_group("ui_manager")
	Inventory.changed.connect(_refresh_hud)
	_refresh_hud()
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

	# --- Bag mode input mapping ---
	if mode == "bag":
		if event.is_action_pressed("ui_up"):
			_move_selection(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_down"):
			_move_selection(1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_left"):
			Inventory.set_selected_slot(Inventory.hotbar_selected - 1)
			_refresh_hud()
			if current_player and current_player.has_method("_update_held_icon"):
				current_player._update_held_icon()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_right"):
			Inventory.set_selected_slot(Inventory.hotbar_selected + 1)
			_refresh_hud()
			if current_player and current_player.has_method("_update_held_icon"):
				current_player._update_held_icon()
			get_viewport().set_input_as_handled()
			return

		# F swap
		if event.is_action_pressed("swap_hotbar"):
			if selection_index >= 0 and selection_index < bag_view_ids.size():
				var id := bag_view_ids[selection_index]
				var ok := Inventory.equip_from_bag(id)
				if ok:
					_set_status("Swapped to slot %d: %s" % [Inventory.hotbar_selected + 1, id], true)
				else:
					_set_status("Cannot swap.", false)
				_refresh_bag()
				_refresh_hud()
			get_viewport().set_input_as_handled()
			return

	# --- Non-bag modes keep your old behavior ---
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

func _resolve_meat() -> String:
	if Inventory.has_item("meat_monster", 1):
		return "meat_monster"
	if Inventory.has_item("pork", 1):
		return "pork"
	return ""

	
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
	if _cust_panel:
		_cust_panel.visible = false
	_lock_player(false)
	current_player = null
	_cust_current_customer = null
	_cust_current_player = null


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
	if mode == "bag":
		return bag_view_ids.size()
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
	cook_money.text = "Money: $%d   Rep: %d" % [Inventory.money, Inventory.reputation]
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

		var have_amt := 0
		var ok := false
		var label_name = String(k)

		if k == "meat":
			var pork_amt := int(Inventory.bag.get("pork", 0))
			var monster_amt := int(Inventory.bag.get("meat_monster", 0))
			have_amt = pork_amt + monster_amt
			ok = have_amt >= need_amt
			label_name = "meat (pork or monster)"
		else:
			have_amt = int(Inventory.bag.get(k, 0))
			ok = have_amt >= need_amt

		var line := Label.new()
		line.text = "- %s x%d (you: %d)" % [label_name, need_amt, have_amt]
		line.modulate = Color(1,1,1,1) if ok else Color(0.45,0.45,0.45,1)
		recipe_detail.add_child(line)


func _refresh_shop():
	shop_money.text = "Money: $%d   Rep: %d" % [Inventory.money, Inventory.reputation]
	for i in shop_list.get_child_count():
		var b: Button = shop_list.get_child(i)
		b.modulate = Color(1,1,1,1) if i == selection_index else Color(0.8,0.8,0.8,1)

# ---------- actions ----------
func _cook_selected():
	var r = recipes[selection_index]

	# 1) Check requirements (category-aware)
	var chosen_meat := ""

	for k in r["needs"].keys():
		var amt := int(r["needs"][k])

		if k == "meat":
			chosen_meat = _resolve_meat()
			if chosen_meat == "":
				_set_status("Need meat (pork or monster meat).", false)
				return
		else:
			if not Inventory.has_item(k, amt):
				_set_status("Missing: %s x%d" % [k, amt], false)
				return


	# 2) Consume requirements
	for k in r["needs"].keys():
		var amt := int(r["needs"][k])

		if k == "meat":
			Inventory.remove_item(chosen_meat, amt)
		else:
			Inventory.remove_item(k, amt)


	# 3) Produce result
	var cooked_id := ""

	for out_id in r["gives"].keys():
		var out_amt := int(r["gives"][out_id])
		Inventory.add_item(out_id, out_amt)
		cooked_id = out_id

		# store metadata if this dish used meat
		if chosen_meat != "":
			if not Inventory.dish_meta.has(out_id):
				Inventory.dish_meta[out_id] = {}
			Inventory.dish_meta[out_id]["meat_type"] = chosen_meat

	if cooked_id != "":
		_show_dish_on_counter(cooked_id)

	_set_status("Cooked: %s" % r["name"], true)


	
func _buy_selected():
	var it = shop_items[selection_index]
	var price := int(it["price"])
	print("BUY CALLED item =", it["id"], "price =", price, "money before =", Inventory.money)

	if Inventory.money < price:
		_set_status("Not enough money.", false)
		toast_on_player("Not enough money")
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



func _refresh_bag() -> void:
	bag_money.text = "Money: $%d   Rep: %d" % [Inventory.money, Inventory.reputation]

	var hint: Label = $BagPanel/VBoxContainer/Hint
	hint.text = "Up/Down: Select Item   Left/Right: Select Slot   F: Swap   Q: Exit"

	for c in bag_list.get_children():
		c.queue_free()

	bag_view_ids.clear()

	var keys := Inventory.bag.keys()
	keys.sort()

	for k in keys:
		var amt := int(Inventory.bag.get(k, 0))
		if amt <= 0:
			continue

		bag_view_ids.append(k)

		var line := Label.new()
		line.text = "%s x%d" % [k, amt]

		var idx := bag_view_ids.size() - 1
		line.modulate = Color(1,1,1,1) if idx == selection_index else Color(0.75,0.75,0.75,1)

		bag_list.add_child(line)

	if bag_view_ids.size() == 0:
		selection_index = 0
	else:
		selection_index = clamp(selection_index, 0, bag_view_ids.size() - 1)



#------------------------------------Cooking------------------------------------

func _show_dish_on_counter(dish_id: String) -> void:
	var map := get_tree().current_scene
	if map == null:
		return

	var dishes_root := map.get_node_or_null("Dishes")
	if dishes_root == null:
		_set_status("No Dishes node.", false)
		return

	var spawn := dishes_root.get_node_or_null("DishSpawnPoint")
	if spawn == null:
		_set_status("No DishSpawnPoint.", false)
		return

	var dish_sprite := dishes_root.get_node_or_null("DishSprite") as Sprite2D
	if dish_sprite == null:
		_set_status("No DishSprite found.", false)
		return

	var tex := _item_icon(dish_id)
	if tex == null:
		_set_status("No texture for: %s" % dish_id, false)
		return

	dish_sprite.texture = tex
	dish_sprite.global_position = spawn.global_position
	dish_sprite.scale = Vector2(0.15, 0.15) # tweak this
	dish_sprite.visible = true



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


# ---------- lightweight feedback helpers ----------
var _toast_root: Control = null
var _blackout: ColorRect = null
var _kill_audio: AudioStreamPlayer = null

func _ensure_feedback_nodes() -> void:
	if _toast_root != null:
		return
	_toast_root = Control.new()
	_toast_root.name = "ToastRoot"
	_toast_root.anchor_left = 0
	_toast_root.anchor_top = 0
	_toast_root.anchor_right = 1
	_toast_root.anchor_bottom = 1
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_root)

	_blackout = ColorRect.new()
	_blackout.name = "Blackout"
	_blackout.anchor_left = 0
	_blackout.anchor_top = 0
	_blackout.anchor_right = 1
	_blackout.anchor_bottom = 1
	_blackout.color = Color(0,0,0,0)
	_blackout.visible = false
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_blackout)

	_kill_audio = AudioStreamPlayer.new()
	_kill_audio.name = "KillAudio"
	_kill_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	# If you add the file later, this will work automatically.
	if ResourceLoader.exists("res://Assets/killsound.wav"):
		_kill_audio.stream = load("res://Assets/killsound.wav")
	add_child(_kill_audio)

func show_toast(world_pos: Vector2, text: String, seconds: float = 1.3) -> void:
	_ensure_feedback_nodes()
	var lab := Label.new()
	lab.text = text
	lab.position = world_pos
	lab.modulate.a = 1.0
	lab.process_mode = Node.PROCESS_MODE_ALWAYS
	_toast_root.add_child(lab)

	# simple float-up + fade (no Tween dependency on paused tree)
	var t := Timer.new()
	t.wait_time = 0.03
	t.one_shot = false
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	_toast_root.add_child(t)

	var elapsed := 0.0
	t.timeout.connect(func():
		elapsed += t.wait_time
		lab.position.y -= 1.2
		lab.modulate.a = clamp(1.0 - (elapsed / seconds), 0.0, 1.0)
		if elapsed >= seconds:
			t.stop()
			lab.queue_free()
			t.queue_free()
	)
	t.start()

func play_kill_cut(duration: float = 0.55) -> void:
	_ensure_feedback_nodes()
	_blackout.visible = true
	_blackout.color = Color(0,0,0,1)
	if _kill_audio and _kill_audio.stream:
		_kill_audio.play()

	# pause the game while black screen is up
	get_tree().paused = true

	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.timeout.connect(func():
		get_tree().paused = false
		_blackout.visible = false
		_blackout.color = Color(0,0,0,0)
		timer.queue_free()
	)
	timer.start()


# ---------- Customer interaction menu ----------
var _cust_panel: PanelContainer = null
var _cust_label: Label = null
var _cust_btn_submit: Button = null
var _cust_btn_kill: Button = null
var _cust_btn_cancel: Button = null
var _cust_current_customer: Node = null
var _cust_current_player: Node = null

func open_customer_menu(player: Node, customer: Node, can_submit: bool, can_kill: bool, want_text: String) -> void:
	_ensure_customer_panel()
	_cust_current_player = player
	_cust_current_customer = customer

	_lock_player(true)
	ui_open = true
	mode = "customer"
	ignore_next_interact = true

	_hide_all()
	_cust_panel.visible = true

	_cust_label.text = want_text
	_cust_btn_submit.disabled = not can_submit
	_cust_btn_kill.disabled = not can_kill

func _ensure_customer_panel() -> void:
	if _cust_panel != null:
		return

	_cust_panel = PanelContainer.new()
	_cust_panel.name = "CustomerPanel"
	_cust_panel.anchor_left = 0.5
	_cust_panel.anchor_top = 0.5
	_cust_panel.anchor_right = 0.5
	_cust_panel.anchor_bottom = 0.5
	_cust_panel.offset_left = -110
	_cust_panel.offset_top = -70
	_cust_panel.offset_right = 110
	_cust_panel.offset_bottom = 70
	_cust_panel.visible = false
	_cust_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_cust_panel)

	var vb := VBoxContainer.new()
	_cust_panel.add_child(vb)

	_cust_label = Label.new()
	_cust_label.text = "Customer"
	vb.add_child(_cust_label)

	_cust_btn_submit = Button.new()
	_cust_btn_submit.text = "Submit Food"
	vb.add_child(_cust_btn_submit)

	_cust_btn_kill = Button.new()
	_cust_btn_kill.text = "Kill (Knife)"
	vb.add_child(_cust_btn_kill)

	_cust_btn_cancel = Button.new()
	_cust_btn_cancel.text = "Cancel"
	vb.add_child(_cust_btn_cancel)

	_cust_btn_submit.pressed.connect(func():
		if _cust_current_customer and _cust_current_customer.has_method("on_player_submit"):
			_cust_current_customer.on_player_submit(_cust_current_player)
		close_customer_menu()
	)

	_cust_btn_kill.pressed.connect(func():
		# run cut first, then kill
		play_kill_cut()
		if _cust_current_customer and _cust_current_customer.has_method("on_player_kill"):
			_cust_current_customer.on_player_kill(_cust_current_player)
		close_customer_menu()
	)

	_cust_btn_cancel.pressed.connect(func():
		close_customer_menu()
	)

func close_customer_menu() -> void:
	ui_open = false
	mode = ""
	if _cust_panel:
		_cust_panel.visible = false
	_lock_player(false)
	_cust_current_customer = null
	_cust_current_player = null

func toast_on_player(text: String) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player == null:
		# fallback top-left
		show_toast(Vector2(30, 30), text)
		return

	var world := (player as Node2D).global_position + Vector2(0, -32)
	var screen := get_viewport().get_canvas_transform() * world
	show_toast(screen, text)
