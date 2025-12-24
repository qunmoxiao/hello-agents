# 隐藏物品脚本
extends Area2D

@export var item_id: String = ""
@export var clue_id: String = ""
@export var hint_text: String = "按E键调查"

var player_in_range = false
var hint_label: Label = null

func _ready():
	# 添加到组
	add_to_group("interactables")
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 创建提示标签
	hint_label = Label.new()
	hint_label.text = hint_text
	hint_label.add_theme_color_override("font_color", Color.WHITE)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 4)
	add_child(hint_label)
	hint_label.position = Vector2(-hint_label.size.x / 2, -40)
	hint_label.visible = false

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		if hint_label:
			hint_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		if hint_label:
			hint_label.visible = false

func _input(event):
	if player_in_range and event.is_action_pressed("ui_accept"):
		# 检查玩家是否正在交互
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("get") and "is_interacting" in player:
			if player.is_interacting:
				return
		
		collect_item()

func collect_item():
	"""收集物品/线索"""
	var collected = false
	
	if item_id != "":
		if has_node("/root/ItemCollection"):
			if ItemCollection.collect_item(item_id):
				collected = true
				print("[INFO] 收集到物品: ", item_id)
	
	if clue_id != "":
		if has_node("/root/ClueManager"):
			if ClueManager.collect_clue(clue_id):
				collected = true
				print("[INFO] 收集到线索: ", clue_id)
	
	if collected:
		# 隐藏物品（可选：播放收集动画）
		queue_free()
	else:
		print("[WARN] 无法收集物品/线索")

