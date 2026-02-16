extends StaticBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

const CLOSED_REGION := Rect2(64, 0, 64, 64)
const OPEN_REGION   := Rect2(0, 0, 64, 64)

var is_open := false

func _ready():
	set_open(false)

func interact(player):
	set_open(not is_open)

func set_open(v: bool) -> void:
	is_open = v

	col.disabled = is_open

	var atlas := sprite.texture as AtlasTexture
	if atlas:
		atlas.region = OPEN_REGION if is_open else CLOSED_REGION
