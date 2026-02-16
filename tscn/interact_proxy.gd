extends Area2D

func interact(player):
	var door = get_parent()
	if door and door.has_method("interact"):
		door.interact(player)
