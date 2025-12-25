# 线索UI脚本
extends CanvasLayer

# 导出变量（可在编辑器中配置）
@export var background_texture: Texture2D = null  # 背景图片（可选）

# 节点引用（需要在场景中配置）
@onready var panel: Panel = $Control/Panel
@onready var background_texture_rect: TextureRect = $Control/Panel/BackgroundTexture
@onready var title_label: Label = $Control/Panel/TitleLabel
@onready var clue_list: VBoxContainer = $Control/Panel/ScrollContainer/ClueList
@onready var scroll_container: ScrollContainer = $Control/Panel/ScrollContainer
@onready var close_button: Button = $Control/Panel/CloseButton
@onready var no_clue_label: Label = $Control/Panel/NoClueLabel
@onready var clue_detail_panel: Panel = $Control/Panel/ClueDetailPanel
@onready var clue_detail_title: Label = $Control/Panel/ClueDetailPanel/TitleLabel
@onready var clue_detail_desc: Label = $Control/Panel/ClueDetailPanel/DescriptionLabel
@onready var clue_detail_close: Button = $Control/Panel/ClueDetailPanel/CloseButton
@onready var clue_detail_icon: TextureRect = $Control/Panel/ClueDetailPanel/IconTexture

func _ready():
	# 添加到组
	add_to_group("clue_ui")
	
	# 初始隐藏
	visible = false
	if clue_detail_panel:
		clue_detail_panel.visible = false
	
	# 连接按钮
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if clue_detail_close:
		clue_detail_close.pressed.connect(_on_detail_close_pressed)
	
	# 连接线索管理器信号
	if has_node("/root/ClueManager"):
		ClueManager.clue_collected.connect(_on_clue_collected)
	
	# 设置背景图片
	if background_texture and background_texture_rect:
		background_texture_rect.texture = background_texture
		background_texture_rect.visible = true
		# 如果有背景图，设置Panel为透明
		if panel:
			var style_box = StyleBoxEmpty.new()
			panel.add_theme_stylebox_override("panel", style_box)
		print("[INFO] 已设置线索UI背景图片")
	elif background_texture_rect:
		background_texture_rect.visible = false
	
	# 设置样式
	_setup_ui_style()
	
	# 初始更新
	update_clue_list()

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
	
	if clue_detail_panel:
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
		clue_detail_panel.add_theme_stylebox_override("panel", detail_style)
	
	if title_label:
		title_label.add_theme_color_override("font_color", Color.WHITE)
		title_label.add_theme_font_size_override("font_size", 56)  # 从40增加到56
	
	if no_clue_label:
		no_clue_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		no_clue_label.add_theme_font_size_override("font_size", 40)  # 增大字体

func _input(event: InputEvent):
	"""处理输入事件"""
	if event.is_action_pressed("ui_cancel") and visible:
		if clue_detail_panel and clue_detail_panel.visible:
			hide_clue_detail()
		else:
			hide_clue_ui()
		get_viewport().set_input_as_handled()

func show_clue_ui():
	"""显示线索UI"""
	visible = true
	update_clue_list()
	
	# 通知玩家进入交互状态
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_interacting"):
		player.set_interacting(true)

func hide_clue_ui():
	"""隐藏线索UI"""
	visible = false
	hide_clue_detail()
	
	# 通知玩家退出交互状态
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_interacting"):
		player.set_interacting(false)

func update_clue_list():
	"""更新线索列表"""
	if not has_node("/root/ClueManager"):
		return
	
	if not clue_list:
		return
	
	# 清空列表
	for child in clue_list.get_children():
		child.queue_free()
	
	# 获取收集的线索
	var collected_clues = ClueManager.get_collected_clues_info()
	
	if collected_clues.is_empty():
		# 显示"无线索"提示
		if no_clue_label:
			no_clue_label.visible = true
		return
	
	if no_clue_label:
		no_clue_label.visible = false
	
	# ⭐ 按章节分组线索
	var clues_by_chapter = {}
	for clue in collected_clues:
		var chapter = clue.get("chapter", 0)
		if chapter not in clues_by_chapter:
			clues_by_chapter[chapter] = []
		clues_by_chapter[chapter].append(clue)
	
	# ⭐ 按章节顺序显示（1, 2, 3）
	var chapters = clues_by_chapter.keys()
	chapters.sort()
	
	for chapter in chapters:
		# ⭐ 创建章节标题（带进度）
		_create_chapter_header(chapter)
		
		# 创建该章节的线索项
		for clue in clues_by_chapter[chapter]:
			_create_clue_item(clue)
		
		# 添加章节分隔
		_create_chapter_separator()

func _create_chapter_header(chapter: int):
	"""创建章节标题（带进度）"""
	var chapter_container = HBoxContainer.new()
	chapter_container.add_theme_constant_override("separation", 15)
	
	# 章节名称
	var chapter_label = Label.new()
	var chapter_name = ""
	match chapter:
		1:
			chapter_name = "第一章：青年时期"
		2:
			chapter_name = "第二章：长安时期"
		3:
			chapter_name = "第三章：晚年时期"
		_:
			chapter_name = "第%d章" % chapter
	
	chapter_label.text = chapter_name
	chapter_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))  # 金色
	chapter_label.add_theme_font_size_override("font_size", 44)
	chapter_label.add_theme_constant_override("outline_size", 4)
	chapter_label.add_theme_color_override("font_outline_color", Color.BLACK)
	chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chapter_container.add_child(chapter_label)
	
	# ⭐ 章节线索进度
	var progress_label = Label.new()
	if has_node("/root/AchievementManager"):
		var progress = AchievementManager.get_chapter_clue_progress(chapter)
		var progress_text = "(%d/%d)" % [progress["collected"], progress["total"]]
		
		# 如果已完成，显示成就图标
		if progress["collected"] >= progress["total"] and progress["total"] > 0:
			progress_text = "🏆 " + progress_text + " 已完成"
			progress_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))  # 金色
		else:
			progress_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))  # 淡蓝色
		
		progress_label.text = progress_text
		progress_label.add_theme_font_size_override("font_size", 36)
		progress_label.add_theme_constant_override("outline_size", 3)
		progress_label.add_theme_color_override("font_outline_color", Color.BLACK)
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		chapter_container.add_child(progress_label)
	
	# 添加左边距
	var outer_container = HBoxContainer.new()
	outer_container.add_theme_constant_override("separation", 0)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	outer_container.add_child(spacer)
	outer_container.add_child(chapter_container)
	outer_container.custom_minimum_size = Vector2(0, 70)  # 增大高度
	
	clue_list.add_child(outer_container)

func _create_chapter_separator():
	"""创建章节分隔线"""
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 4)
	clue_list.add_child(separator)
	
	# 添加间距
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	clue_list.add_child(spacer)

func _create_clue_item(clue: Dictionary):
	"""创建线索项UI"""
	var clue_id = clue.get("clue_id", "")
	var title = clue.get("title", "未知线索")
	var category = clue.get("category", "unknown")
	var icon_path = clue.get("icon", "")
	var source = clue.get("source", "quest")  # 获取线索来源
	
	# ⭐ 创建线索项容器 - 增大尺寸
	var clue_item = HBoxContainer.new()
	clue_item.add_theme_constant_override("separation", 20)  # 增大间距
	clue_item.custom_minimum_size = Vector2(0, 100)  # 从70增加到100
	
	# ⭐ 线索图标（如果有）- 增大图标尺寸
	if icon_path != "":
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(90, 90)  # 从60增加到90
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_texture = load(icon_path)
		if icon_texture:
			icon_rect.texture = icon_texture
		else:
			# 如果加载失败，使用占位符
			var placeholder = Label.new()
			placeholder.text = "🔍"
			placeholder.add_theme_font_size_override("font_size", 72)  # 从48增加到72
			icon_rect.add_child(placeholder)
		clue_item.add_child(icon_rect)
	else:
		# 没有图标时使用占位符 - 增大尺寸
		var placeholder = Label.new()
		placeholder.text = "🔍"
		placeholder.custom_minimum_size = Vector2(90, 90)  # 从60增加到90
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override("font_size", 72)  # 从48增加到72
		clue_item.add_child(placeholder)
	
	# ⭐ 内容容器（垂直布局）
	var content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 8)
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# ⭐ 线索标题按钮 - 增大字体和尺寸
	var title_button = Button.new()
	title_button.text = title
	title_button.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	title_button.add_theme_font_size_override("font_size", 36)  # 从28增加到36
	title_button.custom_minimum_size = Vector2(400, 50)  # 增大尺寸
	title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_button.pressed.connect(func(): show_clue_detail(clue_id))
	content_container.add_child(title_button)
	
	# ⭐ 线索信息行（分类和来源）
	var info_container = HBoxContainer.new()
	info_container.add_theme_constant_override("separation", 15)
	
	# 线索分类标签 - 增大字体
	var category_label = Label.new()
	var category_text = ""
	match category:
		"event":
			category_text = "[事件]"
		"person":
			category_text = "[人物]"
		"location":
			category_text = "[地点]"
		"item":
			category_text = "[物品]"
		_:
			category_text = "[其他]"
	
	category_label.text = category_text
	category_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	category_label.add_theme_font_size_override("font_size", 28)  # 从22增加到28
	info_container.add_child(category_label)
	
	# ⭐ 线索来源标签
	var source_label = Label.new()
	var source_text = ""
	match source:
		"quest":
			source_text = "任务获得"
		"scene":
			source_text = "场景收集"
		_:
			source_text = ""
	
	if source_text != "":
		source_label.text = "• " + source_text
		source_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 1.0))  # 紫色
		source_label.add_theme_font_size_override("font_size", 24)
		info_container.add_child(source_label)
	
	content_container.add_child(info_container)
	clue_item.add_child(content_container)
	
	# 添加到列表
	clue_list.add_child(clue_item)

func show_clue_detail(clue_id: String):
	"""显示线索详情"""
	if not has_node("/root/ClueManager"):
		return
	
	var clue = ClueManager.get_clue_info(clue_id)
	if clue.is_empty():
		return
	
	if clue_detail_panel:
		clue_detail_panel.visible = true
	
	if clue_detail_title:
		clue_detail_title.text = clue.get("title", "未知线索")
	
	# 显示线索图标（如果有）
	if clue_detail_icon:
		var icon_path = clue.get("icon", "")
		if icon_path != "":
			var icon_texture = load(icon_path)
			if icon_texture:
				clue_detail_icon.texture = icon_texture
				clue_detail_icon.visible = true
			else:
				clue_detail_icon.visible = false
		else:
			clue_detail_icon.visible = false
	
	if clue_detail_desc:
		var desc = clue.get("description", "")
		var chapter = clue.get("chapter", 0)
		var source = clue.get("source", "quest")
		var source_text = ""
		match source:
			"quest":
				source_text = "任务获得"
			"scene":
				source_text = "场景收集"
		
		if chapter > 0:
			var chapter_name = ""
			match chapter:
				1:
					chapter_name = "第一章：青年时期"
				2:
					chapter_name = "第二章：长安时期"
				3:
					chapter_name = "第三章：晚年时期"
				_:
					chapter_name = "第%d章" % chapter
			desc = "%s\n来源：%s\n\n%s" % [chapter_name, source_text, desc]
		clue_detail_desc.text = desc
		clue_detail_desc.add_theme_font_size_override("font_size", 32)  # 从24增加到32
		clue_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func hide_clue_detail():
	"""隐藏线索详情"""
	if clue_detail_panel:
		clue_detail_panel.visible = false

func _on_clue_collected(clue_id: String):
	"""线索收集回调"""
	update_clue_list()
	# 可以在这里显示收集提示

func _on_close_button_pressed():
	"""关闭按钮点击"""
	hide_clue_ui()

func _on_detail_close_pressed():
	"""详情关闭按钮点击"""
	hide_clue_detail()

