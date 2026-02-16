extends Area2D

func interact(player):
	var ui = get_tree().get_first_node_in_group("ui_manager")
	if ui:
		ui.open_cooking(player)
