# 快捷键提示UI脚本
extends CanvasLayer

@onready var hint_panel: Panel = $Control/HintPanel
@onready var hint_container: VBoxContainer = $Control/HintPanel/HintContainer

var player: Node = null
var dialogue_ui: Node = null
var is_dialogue_open: bool = false

func _ready():
	add_to_group("shortcut_hint_ui")
	visible = true
	
	_setup_ui_style()
	call_deferred("_update_hints")
	
	# 定期更新提示（检测状态变化）
	var timer = Timer.new()
	timer.wait_time = 0.3  # 更频繁的更新
	timer.timeout.connect(_update_hints)
	timer.autostart = true
	add_child(timer)
	
	# 连接对话系统信号（如果可用）
	call_deferred("_connect_signals")
	
	print("[INFO] 快捷键提示UI已初始化")

func _connect_signals():
	"""连接相关信号"""
	# 尝试连接对话系统的信号
	dialogue_ui = get_tree().get_first_node_in_group("dialogue_system")
	if dialogue_ui:
		# 如果对话系统有信号，连接它们
		if dialogue_ui.has_signal("dialogue_opened"):
			if not dialogue_ui.dialogue_opened.is_connected(_on_dialogue_opened):
				dialogue_ui.dialogue_opened.connect(_on_dialogue_opened)
		if dialogue_ui.has_signal("dialogue_closed"):
			if not dialogue_ui.dialogue_closed.is_connected(_on_dialogue_closed):
				dialogue_ui.dialogue_closed.connect(_on_dialogue_closed)

func _on_dialogue_opened():
	"""对话打开时"""
	call_deferred("_update_hints")

func _on_dialogue_closed():
	"""对话关闭时"""
	call_deferred("_update_hints")

func _setup_ui_style():
	"""设置UI样式"""
	if hint_panel:
		hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hint_panel.offset_left = -500  # 增大宽度，容纳更多内容
		hint_panel.offset_top = -250  # 增大高度
		hint_panel.offset_right = -20
		hint_panel.offset_bottom = -20
		
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.1, 0.1, 0.15, 0.85)  # 半透明深色背景
		style_box.border_color = Color(0.7, 0.7, 0.8, 0.9)  # 浅色边框
		style_box.border_width_left = 3
		style_box.border_width_top = 3
		style_box.border_width_right = 3
		style_box.border_width_bottom = 3
		style_box.corner_radius_top_left = 12
		style_box.corner_radius_top_right = 12
		style_box.corner_radius_bottom_left = 12
		style_box.corner_radius_bottom_right = 12
		style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
		style_box.shadow_size = 6
		style_box.shadow_offset = Vector2(0, 3)
		hint_panel.add_theme_stylebox_override("panel", style_box)
	
	if hint_container:
		hint_container.add_theme_constant_override("separation", 8)

func _update_hints():
	"""更新快捷键提示（根据当前状态）"""
	if not hint_container:
		return
	
	# 清空现有内容
	for child in hint_container.get_children():
		child.queue_free()
	
	# 获取当前状态
	player = get_tree().get_first_node_in_group("player")
	
	# 检查对话是否打开（多种方式查找）
	dialogue_ui = get_tree().get_first_node_in_group("dialogue_system")
	if not dialogue_ui:
		# 尝试通过场景树查找
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node:
			dialogue_ui = main_node.get_node_or_null("DialogueUI")
	
	if dialogue_ui:
		if dialogue_ui.has("visible"):
			is_dialogue_open = dialogue_ui.visible
		else:
			is_dialogue_open = false
	else:
		is_dialogue_open = false
	
	# 根据状态显示不同的快捷键
	if is_dialogue_open:
		# 对话中：显示对话相关快捷键
		_create_hint_item("ESC", "关闭对话", Color(1.0, 0.7, 0.7, 1.0))
		_create_hint_item("Enter", "发送消息", Color(0.7, 1.0, 0.7, 1.0))
	else:
		# 正常游戏状态：显示所有可用快捷键
		_create_hint_item("WASD", "移动", Color(0.8, 0.8, 0.9, 1.0))
		
		# 检查是否有附近的NPC
		var has_nearby_npc = false
		if player:
			if player.has_method("get_nearby_npc"):
				var nearby_npc = player.get_nearby_npc()
				has_nearby_npc = (nearby_npc != null)
			elif player.has("nearby_npc"):
				has_nearby_npc = (player.nearby_npc != null)
		
		if has_nearby_npc:
			_create_hint_item("E", "与NPC对话", Color(1.0, 0.9, 0.3, 1.0))  # 高亮显示
		
		_create_hint_item("B", "场景指南", Color(0.6, 0.9, 1.0, 1.0))
		_create_hint_item("C", "线索", Color(0.9, 0.8, 0.6, 1.0))
		_create_hint_item("I", "背包", Color(0.8, 0.9, 0.6, 1.0))

func _create_hint_item(key: String, description: String, key_color: Color = Color(1.0, 0.85, 0.3, 1.0)):
	"""创建快捷键提示项"""
	var hint_item = HBoxContainer.new()
	hint_item.add_theme_constant_override("separation", 12)
	
	# 快捷键标签（大字体，高亮）
	var key_label = Label.new()
	key_label.text = "[" + key + "]"
	key_label.add_theme_font_size_override("font_size", 42)  # 更大字体，适合青少年
	key_label.add_theme_color_override("font_color", key_color)
	key_label.custom_minimum_size = Vector2(150, 0)  # 固定宽度，对齐
	hint_item.add_child(key_label)
	
	# 描述标签
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 38)  # 更大字体，适合青少年
	desc_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_item.add_child(desc_label)
	
	hint_container.add_child(hint_item)
