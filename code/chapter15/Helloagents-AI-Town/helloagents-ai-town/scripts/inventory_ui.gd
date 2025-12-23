# 背包UI脚本
extends CanvasLayer

# 导出变量（可在编辑器中配置）
@export var background_texture: Texture2D = null  # 背景图片（可选）
@export var columns: int = 4  # 网格列数

# 节点引用（需要在场景中配置）
@onready var panel: Panel = $Control/Panel
@onready var background_texture_rect: TextureRect = $Control/Panel/BackgroundTexture
@onready var title_label: Label = $Control/Panel/TitleLabel
@onready var item_grid: GridContainer = $Control/Panel/ScrollContainer/ItemGrid
@onready var scroll_container: ScrollContainer = $Control/Panel/ScrollContainer
@onready var close_button: Button = $Control/Panel/CloseButton
@onready var no_item_label: Label = $Control/Panel/NoItemLabel
@onready var item_detail_panel: Panel = $Control/Panel/ItemDetailPanel
@onready var item_detail_name: Label = $Control/Panel/ItemDetailPanel/NameLabel
@onready var item_detail_desc: Label = $Control/Panel/ItemDetailPanel/DescriptionLabel
@onready var item_detail_content: Label = $Control/Panel/ItemDetailPanel/ContentLabel
@onready var item_detail_icon: TextureRect = $Control/Panel/ItemDetailPanel/IconTexture
@onready var item_detail_close: Button = $Control/Panel/ItemDetailPanel/CloseButton

func _ready():
	# 添加到组
	add_to_group("inventory_ui")
	
	# 初始隐藏
	visible = false
	if item_detail_panel:
		item_detail_panel.visible = false
	
	# 连接按钮
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if item_detail_close:
		item_detail_close.pressed.connect(_on_detail_close_pressed)
	
	# 连接物品收集系统信号
	if has_node("/root/ItemCollection"):
		ItemCollection.item_collected.connect(_on_item_collected)
	
	# 设置网格列数
	if item_grid:
		item_grid.columns = columns
	
	# 设置背景图片
	if background_texture and background_texture_rect:
		background_texture_rect.texture = background_texture
		background_texture_rect.visible = true
		# 如果有背景图，设置Panel为透明
		if panel:
			var style_box = StyleBoxEmpty.new()
			panel.add_theme_stylebox_override("panel", style_box)
		print("[INFO] 已设置背包UI背景图片")
	elif background_texture_rect:
		background_texture_rect.visible = false
	
	# 设置样式
	_setup_ui_style()
	
	# 初始更新
	update_item_list()

func _setup_ui_style():
	"""设置UI样式"""
	if panel:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
		style_box.border_color = Color(0.3, 0.3, 0.4, 1.0)
		style_box.border_width_left = 4
		style_box.border_width_top = 4
		style_box.border_width_right = 4
		style_box.border_width_bottom = 4
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", style_box)
	
	if item_detail_panel:
		var detail_style = StyleBoxFlat.new()
		detail_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
		detail_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
		detail_style.border_width_left = 4
		detail_style.border_width_top = 4
		detail_style.border_width_right = 4
		detail_style.border_width_bottom = 4
		detail_style.corner_radius_top_left = 10
		detail_style.corner_radius_top_right = 10
		detail_style.corner_radius_bottom_left = 10
		detail_style.corner_radius_bottom_right = 10
		item_detail_panel.add_theme_stylebox_override("panel", detail_style)
	
	if title_label:
		title_label.add_theme_color_override("font_color", Color.WHITE)
		title_label.add_theme_font_size_override("font_size", 40)
	
	if no_item_label:
		no_item_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))

func _input(event: InputEvent):
	"""处理输入事件"""
	if event.is_action_pressed("ui_cancel") and visible:
		if item_detail_panel and item_detail_panel.visible:
			hide_item_detail()
		else:
			hide_inventory_ui()
		get_viewport().set_input_as_handled()

func show_inventory_ui():
	"""显示背包UI"""
	visible = true
	update_item_list()
	
	# 通知玩家进入交互状态
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_interacting"):
		player.set_interacting(true)

func hide_inventory_ui():
	"""隐藏背包UI"""
	visible = false
	hide_item_detail()
	
	# 通知玩家退出交互状态
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_interacting"):
		player.set_interacting(false)

func update_item_list():
	"""更新物品列表"""
	if not has_node("/root/ItemCollection"):
		return
	
	if not item_grid:
		return
	
	# 清空列表
	for child in item_grid.get_children():
		child.queue_free()
	
	# 获取收集的物品
	var collected_items = ItemCollection.get_collected_items_info()
	
	if collected_items.is_empty():
		# 显示"无物品"提示
		if no_item_label:
			no_item_label.visible = true
		return
	
	if no_item_label:
		no_item_label.visible = false
	
	# 创建物品项
	for item in collected_items:
		_create_item_slot(item)

func _create_item_slot(item: Dictionary):
	"""创建物品槽UI"""
	var item_id = item.get("item_id", "")
	var name = item.get("name", "未知物品")
	var count = item.get("count", 1)
	var item_type = item.get("type", "unknown")
	
	# 创建物品槽容器
	var item_slot = VBoxContainer.new()
	item_slot.custom_minimum_size = Vector2(150, 180)
	item_slot.add_theme_constant_override("separation", 8)
	
	# 物品图标（支持加载实际图标）
	var icon_path = item.get("icon", "")
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(100, 100)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_rect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if icon_path != "":
		var icon_texture = load(icon_path)
		if icon_texture:
			icon_rect.texture = icon_texture
		else:
			# 如果加载失败，使用占位符
			var placeholder = Label.new()
			placeholder.text = "📦"
			placeholder.add_theme_font_size_override("font_size", 64)
			icon_rect.add_child(placeholder)
	else:
		# 没有图标时使用占位符
		var placeholder = Label.new()
		placeholder.text = "📦"
		placeholder.add_theme_font_size_override("font_size", 64)
		icon_rect.add_child(placeholder)
	
	item_slot.add_child(icon_rect)
	
	# 物品名称
	var name_label = Label.new()
	name_label.text = name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_slot.add_child(name_label)
	
	# 物品数量（如果可堆叠）
	if item.get("stackable", false) and count > 1:
		var count_label = Label.new()
		count_label.text = "x%d" % count
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
		count_label.add_theme_font_size_override("font_size", 20)
		item_slot.add_child(count_label)
	
	# 添加点击区域
	var click_area = Control.new()
	click_area.custom_minimum_size = item_slot.custom_minimum_size
	click_area.gui_input.connect(func(event): _on_item_clicked(event, item_id))
	item_slot.add_child(click_area)
	
	# 设置背景样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.25, 0.8)
	style_box.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", style_box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_slot.add_child(panel)
	item_slot.move_child(panel, 0)  # 移到最底层
	
	# 添加到网格
	item_grid.add_child(item_slot)

func _on_item_clicked(event: InputEvent, item_id: String):
	"""物品点击事件"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_item_detail(item_id)

func show_item_detail(item_id: String):
	"""显示物品详情"""
	if not has_node("/root/ItemCollection"):
		return
	
	var item = ItemCollection.get_item_info(item_id)
	if item.is_empty():
		return
	
	if item_detail_panel:
		item_detail_panel.visible = true
	
	if item_detail_name:
		item_detail_name.text = item.get("name", "未知物品")
	
	# 显示物品图标（如果有）
	if item_detail_icon:
		var icon_path = item.get("icon", "")
		if icon_path != "":
			var icon_texture = load(icon_path)
			if icon_texture:
				item_detail_icon.texture = icon_texture
				item_detail_icon.visible = true
			else:
				item_detail_icon.visible = false
		else:
			item_detail_icon.visible = false
	
	if item_detail_desc:
		var desc = item.get("description", "")
		var item_type = item.get("type", "")
		var rarity = item.get("rarity", "common")
		
		var type_text = ""
		match item_type:
			"poem":
				type_text = "诗词"
			"book":
				type_text = "书籍"
			"tool":
				type_text = "工具"
			_:
				type_text = "其他"
		
		var rarity_text = ""
		match rarity:
			"common":
				rarity_text = "普通"
			"rare":
				rarity_text = "稀有"
			"epic":
				rarity_text = "史诗"
			"legendary":
				rarity_text = "传说"
			_:
				rarity_text = "普通"
		
		desc = "类型: %s | 品质: %s\n\n%s" % [type_text, rarity_text, desc]
		item_detail_desc.text = desc
		item_detail_desc.add_theme_font_size_override("font_size", 24)
		item_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if item_detail_content:
		var content = item.get("content", "")
		if content != "":
			item_detail_content.text = content
			item_detail_content.visible = true
			item_detail_content.add_theme_font_size_override("font_size", 22)
			item_detail_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			item_detail_content.visible = false

func hide_item_detail():
	"""隐藏物品详情"""
	if item_detail_panel:
		item_detail_panel.visible = false

func _on_item_collected(item_id: String, count: int):
	"""物品收集回调"""
	update_item_list()
	# 可以在这里显示收集提示

func _on_close_button_pressed():
	"""关闭按钮点击"""
	hide_inventory_ui()

func _on_detail_close_pressed():
	"""详情关闭按钮点击"""
	hide_item_detail()

