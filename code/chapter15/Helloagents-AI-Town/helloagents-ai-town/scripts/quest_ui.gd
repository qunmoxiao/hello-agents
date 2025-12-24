# 任务UI脚本
extends CanvasLayer

# 导出变量（可在编辑器中配置）
@export var background_texture: Texture2D = null  # 背景图片（可选）

# 节点引用（需要在场景中配置）
@onready var panel: Panel = $Control/Panel
@onready var background_texture_rect: TextureRect = $Control/Panel/BackgroundTexture
@onready var title_label: Label = $Control/Panel/TitleLabel
@onready var chapter_progress_label: Label = $Control/Panel/ChapterProgressLabel  # ⭐ 章节进度标签
@onready var quest_list: VBoxContainer = $Control/Panel/ScrollContainer/QuestList
@onready var scroll_container: ScrollContainer = $Control/Panel/ScrollContainer
@onready var close_button: Button = $Control/Panel/CloseButton
@onready var no_quest_label: Label = $Control/Panel/NoQuestLabel

var quest_item_scene: PackedScene = null

func _ready():
	# 添加到组
	add_to_group("quest_ui")
	
	# 初始显示（左上角常驻显示）
	visible = true
	
	# 连接按钮
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# ⭐ 连接任务管理器信号（确保信号正确连接）
	if has_node("/root/QuestManager"):
		if not QuestManager.quest_started.is_connected(_on_quest_started):
			QuestManager.quest_started.connect(_on_quest_started)
		if not QuestManager.quest_completed.is_connected(_on_quest_completed):
			QuestManager.quest_completed.connect(_on_quest_completed)
		if not QuestManager.quest_progress_updated.is_connected(_on_quest_progress_updated):
			QuestManager.quest_progress_updated.connect(_on_quest_progress_updated)
			print("[INFO] ✅ 已连接任务进度更新信号")
		if not QuestManager.chapter_completed.is_connected(_on_chapter_completed):
			QuestManager.chapter_completed.connect(_on_chapter_completed)
		print("[INFO] ✅ 任务UI信号连接完成")
	else:
		print("[WARN] ⚠️ QuestManager未找到，无法连接信号")
	
	# 设置背景图片
	if background_texture and background_texture_rect:
		background_texture_rect.texture = background_texture
		background_texture_rect.visible = true
		# 如果有背景图，设置Panel为透明
		if panel:
			var style_box = StyleBoxEmpty.new()
			panel.add_theme_stylebox_override("panel", style_box)
		print("[INFO] 已设置任务UI背景图片")
	elif background_texture_rect:
		background_texture_rect.visible = false
	
	# 设置样式
	_setup_ui_style()
	
	# ⭐ 初始化章节进度标签（如果场景中没有）
	if not chapter_progress_label:
		var progress_label = panel.get_node_or_null("ChapterProgressLabel")
		if progress_label:
			chapter_progress_label = progress_label
		else:
			# 如果场景中没有，创建一个
			chapter_progress_label = Label.new()
			chapter_progress_label.name = "ChapterProgressLabel"
			chapter_progress_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
			chapter_progress_label.offset_top = 65.0
			chapter_progress_label.offset_bottom = 95.0
			chapter_progress_label.offset_left = 10.0
			chapter_progress_label.offset_right = -10.0
			chapter_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chapter_progress_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 1.0))
			chapter_progress_label.add_theme_font_size_override("font_size", 28)
			panel.add_child(chapter_progress_label)
	
	# ⭐ 设置任务列表容器的统一间距和布局
	if quest_list:
		quest_list.add_theme_constant_override("separation", 12)  # 统一间距12px
		quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 初始更新
	update_quest_list()
	
	# ⭐ 定期检查并更新任务列表（确保进度实时显示）
	call_deferred("_start_periodic_update")

func _setup_ui_style():
	"""设置UI样式 - 美化版本"""
	if panel:
		# ⭐ 创建更美观的背景样式（渐变效果、柔和阴影）
		var style_box = StyleBoxFlat.new()
		# 使用更柔和的深色背景，带一点蓝色调
		style_box.bg_color = Color(0.15, 0.18, 0.25, 0.96)  # 深蓝灰色，更柔和
		# 使用金色边框，更有质感
		style_box.border_color = Color(0.9, 0.75, 0.4, 1.0)  # 金色边框
		style_box.border_width_left = 5
		style_box.border_width_top = 5
		style_box.border_width_right = 5
		style_box.border_width_bottom = 5
		# 更大的圆角，更现代
		style_box.corner_radius_top_left = 15
		style_box.corner_radius_top_right = 15
		style_box.corner_radius_bottom_left = 15
		style_box.corner_radius_bottom_right = 15
		# 添加阴影效果（通过边框实现）
		style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		style_box.shadow_size = 8
		style_box.shadow_offset = Vector2(0, 4)
		panel.add_theme_stylebox_override("panel", style_box)
	
	# ⭐ 标题使用渐变金色，更有质感
	if title_label:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))  # 金色
		title_label.add_theme_font_size_override("font_size", 44)  # 稍大一些
	
	# ⭐ 章节进度使用更亮的蓝色
	if chapter_progress_label:
		chapter_progress_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0, 1.0))  # 亮蓝色
		chapter_progress_label.add_theme_font_size_override("font_size", 30)  # 稍大一些
	
	if no_quest_label:
		no_quest_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))  # 更亮的灰色

func _input(event: InputEvent):
	"""处理输入事件（任务UI常驻显示，不再响应ESC键）"""
	pass

func show_quest_ui():
	"""显示任务UI（已改为常驻显示，此函数保留用于兼容）"""
	visible = true
	update_quest_list()

func hide_quest_ui():
	"""隐藏任务UI（已改为常驻显示，此函数保留用于兼容）"""
	visible = false

func update_quest_list():
	"""更新任务列表 - 显示当前章节的所有任务（已完成、进行中、未开始）"""
	if not has_node("/root/QuestManager"):
		return
	
	if not quest_list:
		return
	
	# 清空列表
	for child in quest_list.get_children():
		child.queue_free()
	
	# ⭐ 获取当前章节（根据玩家位置）
	var current_chapter = _get_current_chapter()
	
	# ⭐ 更新章节进度显示
	_update_chapter_progress(current_chapter)
	
	# ⭐ 获取当前章节的所有任务（从任务数据库）
	var quest_database = QuestManager.get_quest_database()
	var chapter_quests = []
	
	# 收集当前章节的所有任务
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		var quest_chapter = quest.get("chapter", 1)
		
		if quest_chapter == current_chapter:
			chapter_quests.append(quest_id)
	
	# ⭐ 按任务状态排序：进行中 → 未开始 → 已完成
	chapter_quests.sort_custom(func(a, b):
		var a_completed = QuestManager.is_quest_completed(a)
		var a_active = QuestManager.is_quest_active(a)
		var b_completed = QuestManager.is_quest_completed(b)
		var b_active = QuestManager.is_quest_active(b)
		
		# 进行中的任务优先
		if a_active and not b_active:
			return true
		if not a_active and b_active:
			return false
		
		# 已完成的任务最后
		if a_completed and not b_completed:
			return false
		if not a_completed and b_completed:
			return true
		
		# 其他情况按ID排序
		return a < b
	)
	
	if chapter_quests.is_empty():
		# 显示"无任务"提示
		if no_quest_label:
			no_quest_label.visible = true
			no_quest_label.text = "当前章节暂无任务"
		return
	
	if no_quest_label:
		no_quest_label.visible = false
	
	# ⭐ 创建所有任务项（包括已完成、进行中、未开始）
	for quest_id in chapter_quests:
		_create_quest_item(quest_id)

func _get_current_chapter() -> int:
	"""获取当前章节（根据玩家位置）"""
	# 区域1 = 章节1，区域2 = 章节2，区域3 = 章节3
	if has_node("/root/RegionManager"):
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var player_x = player.global_position.x
			var current_region = RegionManager.get_region_from_x(player_x)
			return current_region
		else:
			# 如果找不到玩家，根据解锁的区域判断
			if RegionManager:
				var unlocked_regions = RegionManager.unlocked_regions
				if unlocked_regions != null and unlocked_regions.size() > 0:
					return unlocked_regions[-1]  # 返回最大解锁区域
	return 1  # 默认返回章节1

func _update_chapter_progress(chapter: int):
	"""更新章节进度显示（已完成任务/总任务）"""
	if not has_node("/root/QuestManager"):
		return
	
	if not chapter_progress_label:
		return
	
	# ⭐ 获取当前章节的所有主任务（is_main: true）
	var total_quests = 0
	var completed_quests = 0
	
	# ⭐ 从任务数据库获取所有任务
	var quest_database = QuestManager.get_quest_database()
	if not quest_database or quest_database.is_empty():
		print("[WARN] 无法获取任务数据库或数据库为空")
		chapter_progress_label.text = "章节 %d: 加载中..." % chapter
		return
	
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		var quest_chapter = quest.get("chapter", 1)
		var is_main = quest.get("is_main", false)
		
		# 只统计主任务
		if quest_chapter == chapter and is_main:
			total_quests += 1
			# 检查是否已完成
			if QuestManager.is_quest_completed(quest_id):
				completed_quests += 1
	
	# ⭐ 更新进度显示
	if total_quests > 0:
		chapter_progress_label.text = "章节 %d: %d/%d 任务完成" % [chapter, completed_quests, total_quests]
		chapter_progress_label.visible = true
		#print("[DEBUG] 📊 章节进度更新: 章节 ", chapter, " ", completed_quests, "/", total_quests, " 任务完成")
	else:
		chapter_progress_label.text = "章节 %d: 暂无任务" % chapter
		chapter_progress_label.visible = true

func _create_quest_item(quest_id: String):
	"""创建任务项UI - 支持已完成、进行中、未开始的任务"""
	# ⭐ 获取任务信息（从任务数据库）
	var quest = QuestManager.get_quest_info(quest_id)
	if quest.is_empty():
		print("[WARN] 任务不存在: ", quest_id)
		return
	
	# ⭐ 判断任务状态（简化版：只在名称后显示状态）
	var is_completed = QuestManager.is_quest_completed(quest_id)
	var is_active = QuestManager.is_quest_active(quest_id)
	var status_text = ""
	
	if is_completed:
		status_text = "（已完成）"
	elif is_active:
		status_text = "（进行中）"
	else:
		status_text = "（未开始）"
	
	# ⭐ 获取任务数据（如果是进行中的任务）
	var quest_data = {}
	if is_active:
		quest_data = QuestManager.get_active_quest_data(quest_id)
	else:
		# 对于已完成或未开始的任务，创建空数据
		quest_data = {"quest": quest, "progress": 0}
	
	# ⭐ 创建任务项容器（卡片式设计）- 使用MarginContainer作为外层（解决重叠问题）
	var quest_item_container = MarginContainer.new()
	quest_item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⭐ MarginContainer在VBoxContainer中能正确计算高度
	
	# ⭐ 统一的背景样式（不再根据状态区分）
	var item_style = StyleBoxFlat.new()
	item_style.bg_color = Color(0.2, 0.25, 0.3, 0.7)  # 统一的深蓝灰色背景
	item_style.border_color = Color(0.6, 0.6, 0.7, 0.8)  # 统一的浅灰色边框
	
	item_style.border_width_left = 3
	item_style.border_width_top = 3
	item_style.border_width_right = 3
	item_style.border_width_bottom = 3
	item_style.corner_radius_top_left = 12
	item_style.corner_radius_top_right = 12
	item_style.corner_radius_bottom_left = 12
	item_style.corner_radius_bottom_right = 12
	item_style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	item_style.shadow_size = 4
	item_style.shadow_offset = Vector2(0, 2)
	
	# ⭐ 创建Panel作为背景层（填充整个MarginContainer）
	var panel_bg = Panel.new()
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 忽略鼠标事件
	panel_bg.add_theme_stylebox_override("panel", item_style)
	quest_item_container.add_child(panel_bg)
	
	# ⭐ 创建内部容器（水平布局：图标+内容）- 不使用PRESET_FULL_RECT
	var quest_item = HBoxContainer.new()
	quest_item.add_theme_constant_override("separation", 18)  # 统一间距
	quest_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⭐ 使用MarginContainer设置内边距
	quest_item_container.add_theme_constant_override("margin_left", 15)
	quest_item_container.add_theme_constant_override("margin_top", 15)
	quest_item_container.add_theme_constant_override("margin_right", 15)
	quest_item_container.add_theme_constant_override("margin_bottom", 15)
	quest_item_container.add_child(quest_item)
	
	# ⭐ 任务图标（统一尺寸和对齐）- 优化版本
	var icon_container = VBoxContainer.new()
	# ⭐ VBoxContainer默认使用容器布局模式，无需显式设置
	icon_container.custom_minimum_size = Vector2(90, 0)  # 固定宽度，高度自适应
	icon_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 垂直居中
	
	var quest_icon_path = quest.get("icon", "")
	if quest_icon_path != "":
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(90, 90)  # 统一尺寸
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_texture = load(quest_icon_path)
		if icon_texture:
			icon_rect.texture = icon_texture
		else:
			# 如果加载失败，使用占位符
			var placeholder = Label.new()
			placeholder.text = "📋"
			placeholder.add_theme_font_size_override("font_size", 60)
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_rect.add_child(placeholder)
		icon_container.add_child(icon_rect)
	else:
		# ⭐ 没有图标时使用占位符 - 统一尺寸
		var placeholder = Label.new()
		placeholder.text = "📋"
		placeholder.custom_minimum_size = Vector2(90, 90)  # 统一尺寸
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override("font_size", 60)  # 统一字体大小
		icon_container.add_child(placeholder)
	
	quest_item.add_child(icon_container)
	
	# ⭐ 内容容器（垂直布局）- 简化版：名称、描述、提示
	var content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 10)  # 统一间距10px
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# ⭐ 任务标题 - 简化版：名称+状态
	var title_label = Label.new()
	var quest_title = quest.get("title", "未知任务")
	title_label.text = quest_title + status_text  # 直接在名称后添加状态
	title_label.add_theme_font_size_override("font_size", 38)  # 统一字体大小
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 自动换行
	# ⭐ 根据任务状态调整标题颜色
	if is_completed:
		title_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7, 1.0))  # 亮绿色
	elif is_active:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))  # 亮金色
	else:
		title_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))  # 浅灰色
	content_container.add_child(title_label)
	
	# ⭐ 任务描述 - 简化版：统一颜色
	var desc_label = Label.new()
	desc_label.text = quest.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 26)  # 统一字体大小
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 自动换行
	# ⭐ 统一使用白色，提高可读性
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))  # 浅白色
	content_container.add_child(desc_label)
	
	# ⭐ 如果是进行中的任务，显示进度信息（对话任务和答题任务不显示进度）
	if is_active:
		var quest_type = quest.get("type", "")
		var progress_info = ""
		
		match quest_type:
			"dialogue":
				# ⭐ 对话任务不显示进度
				pass
			"quiz":
				# ⭐ 答题任务不显示进度
				pass
			"collection":
				#var collected_items = quest_data.get("collected_items", [])
				#var progress = collected_items.size()
				#var required_count = quest.get("required_count", 1)
				#progress_info = "进度: %d/%d 物品" % [progress, required_count]
				pass
			"delivery":
				# ⭐ 配送任务不显示进度
				pass

		if progress_info != "":
			var progress_label = Label.new()
			progress_label.text = progress_info
			progress_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0, 1.0))  # 亮蓝色
			progress_label.add_theme_font_size_override("font_size", 24)
			content_container.add_child(progress_label)
	
	# ⭐ 任务提示 - 美化版本
	var hint = quest.get("hint", "")
	if hint != "":
		var hint_container = HBoxContainer.new()
		hint_container.add_theme_constant_override("separation", 8)
		
		# 提示图标
		var hint_icon = Label.new()
		hint_icon.text = "💡"
		hint_icon.add_theme_font_size_override("font_size", 24)
		hint_container.add_child(hint_icon)
		
		# 提示文本
		var hint_label = Label.new()
		hint_label.text = "提示: " + hint
		hint_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))  # 浅金色
		hint_label.add_theme_font_size_override("font_size", 24)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_container.add_child(hint_label)
		
		content_container.add_child(hint_container)
	
	# 将内容容器添加到任务项
	quest_item.add_child(content_container)
	
	# ⭐ 添加到列表（间距由quest_list的separation统一管理，无需额外spacer）
	quest_list.add_child(quest_item_container)

func _on_quest_started(quest_id: String):
	"""任务开始回调"""
	update_quest_list()

func _on_quest_completed(quest_id: String):
	"""任务完成回调"""
	# ⭐ 更新章节进度
	var current_chapter = _get_current_chapter()
	_update_chapter_progress(current_chapter)
	update_quest_list()
	# 可以在这里显示完成提示

func _on_quest_progress_updated(quest_id: String, progress: int, total: int):
	"""任务进度更新回调"""
	# ⭐ 立即更新任务列表和章节进度，确保进度实时显示
	print("[DEBUG] ⚡ 任务进度更新信号: ", quest_id, " 进度: ", progress, "/", total)
	# 强制立即更新
	var current_chapter = _get_current_chapter()
	_update_chapter_progress(current_chapter)
	call_deferred("update_quest_list")

func _on_chapter_completed(chapter: int, next_region: int):
	"""章节完成回调"""
	print("[INFO] 🎉 章节 ", chapter, " 完成，解锁区域 ", next_region)
	
	# ⭐ 显示章节完成提示
	_show_chapter_completion_notification(chapter, next_region)
	
	# ⭐ 更新任务列表（显示下一章节的任务）
	call_deferred("update_quest_list")

func _show_chapter_completion_notification(chapter: int, next_region: int):
	"""显示章节完成通知"""
	# ⭐ 在任务UI中显示完成提示（在ChapterProgressLabel下方）
	# 创建一个临时的通知标签
	var notification = Label.new()
	notification.text = "🎉 章节 %d 完成！\n区域 %d 已解锁！" % [chapter, next_region]
	notification.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))  # 金色
	notification.add_theme_font_size_override("font_size", 28)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# ⭐ 添加到Panel（在ChapterProgressLabel下方）
	if panel:
		# 设置位置（使用anchors确保正确对齐）
		notification.set_anchors_preset(Control.PRESET_TOP_WIDE)
		
		# ⭐ 计算位置：在ChapterProgressLabel下方
		# ChapterProgressLabel的offset_bottom是110，通知显示在其下方
		var notification_top = 120.0  # 从110向下移动10px
		var notification_height = 50.0  # 通知高度
		
		notification.offset_top = notification_top
		notification.offset_bottom = notification_top + notification_height
		notification.offset_left = 10
		notification.offset_right = -10
		panel.add_child(notification)
		
		print("[INFO] 显示章节完成通知: 章节 ", chapter, " 完成，区域 ", next_region, " 已解锁，位置: ", notification_top)
		
		# 5秒后淡出并删除
		await get_tree().create_timer(5.0).timeout
		var tween = create_tween()
		if tween:
			tween.tween_property(notification, "modulate:a", 0.0, 1.0)
			tween.tween_callback(notification.queue_free)

func _start_periodic_update():
	"""定期更新任务列表（确保进度实时显示）"""
	# ⭐ 每0.3秒更新一次任务列表，确保进度实时显示
	while true:
		await get_tree().create_timer(0.3).timeout
		if visible:
			update_quest_list()

func _on_close_button_pressed():
	"""关闭按钮点击"""
	hide_quest_ui()
