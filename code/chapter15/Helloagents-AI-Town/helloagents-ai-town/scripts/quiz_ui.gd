# 答题UI脚本
extends CanvasLayer

signal quiz_completed(quiz_id: String, passed: bool)

# ==================== 导出变量（可在编辑器中配置）====================
@export var background_texture: Texture2D = null  # 背景图片（可选）
@export var option_button_width: float = 500.0  # 选项按钮宽度（默认500，可根据容器宽度调整）
@export var option_button_font_size: int = 48  # 选项按钮字体大小（默认48）
@export var option_spacing: int = 18  # 选项按钮之间的间距（默认18像素）

var current_quiz: Dictionary = {}
var current_questions: Array = []
var current_question_index: int = 0
var correct_count: int = 0
var quiz_id: String = ""

# 答题历史记录：记录每道题的答案和选择
var answer_history: Array = []  # [{question_index, question, selected_option, correct_option, is_correct}, ...]

# 节点引用
var panel: Panel
var background_texture_rect: TextureRect
var title_label: Label
var question_label: Label
var options_container: VBoxContainer
var progress_label: Label
var feedback_label: Label
var close_button: Button
var history_button: Button  # 历史查看按钮
var history_panel: Panel  # 历史查看面板

var api_client: Node = null

func _ready():
	# 添加到quiz_ui组（必须在最前面，确保其他代码可以找到它）
	add_to_group("quiz_ui")
	
	# 获取节点引用（注意：现在结构是 CanvasLayer -> Control -> Panel）
	panel = get_node_or_null("Control/Panel")
	background_texture_rect = get_node_or_null("Control/Panel/BackgroundTexture")
	title_label = get_node_or_null("Control/Panel/TitleLabel")
	question_label = get_node_or_null("Control/Panel/QuestionLabel")
	options_container = get_node_or_null("Control/Panel/OptionsWrapper/OptionsContainer")
	progress_label = get_node_or_null("Control/Panel/ProgressLabel")
	feedback_label = get_node_or_null("Control/Panel/FeedbackLabel")
	close_button = get_node_or_null("Control/Panel/CloseButton")
	
	# 设置背景图片（如果提供了）
	if background_texture and background_texture_rect:
		background_texture_rect.texture = background_texture
		background_texture_rect.visible = true
		# 如果有背景图，设置Panel为透明，让背景图显示
		if panel:
			var style_box = StyleBoxEmpty.new()
			panel.add_theme_stylebox_override("panel", style_box)
		print("[INFO] 已设置答题UI背景图片")
	elif background_texture_rect:
		background_texture_rect.visible = false
	
	# 设置Panel不透明（如果没有背景图片）
	if panel and not background_texture:
		# 设置Panel样式为不透明
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)  # 深色半透明背景
		style_box.border_color = Color(0.3, 0.3, 0.4, 1.0)  # 边框颜色
		style_box.border_width_left = 4
		style_box.border_width_top = 4
		style_box.border_width_right = 4
		style_box.border_width_bottom = 4
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", style_box)
		print("[INFO] 已设置Panel不透明背景")
	
	# 设置文字颜色（适配卷轴背景的浅色）
	_setup_text_colors()
	
	# 验证节点引用
	print("[INFO] 答题UI节点引用状态:")
	print("  - panel: ", panel != null)
	print("  - background_texture_rect: ", background_texture_rect != null)
	print("  - title_label: ", title_label != null)
	print("  - question_label: ", question_label != null)
	print("  - options_container: ", options_container != null)
	print("  - progress_label: ", progress_label != null)
	print("  - feedback_label: ", feedback_label != null)
	print("  - close_button: ", close_button != null)
	
	# 初始隐藏
	visible = false
	
	# 连接关闭按钮（一直可用）
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
		close_button.disabled = false  # 一直可用
		# 设置关闭按钮样式与进度标签一致
		_setup_close_button_style()
	else:
		print("[WARN] CloseButton未找到")
	
	# 创建历史查看按钮
	#_create_history_button()
	
	# 创建历史查看面板
	#_create_history_panel()
	
	print("[INFO] 答题UI已初始化 (节点名: %s, 已添加到quiz_ui组)" % name)
	
	# 验证是否成功添加到组
	if is_in_group("quiz_ui"):
		print("[INFO] ✅ QuizUI已成功添加到quiz_ui组")
	else:
		print("[ERROR] ❌ QuizUI未能添加到quiz_ui组")

	# 连接 APIClient, 用于获取动态题目
	api_client = get_node_or_null("/root/APIClient")
	if api_client:
		if api_client.has_signal("quiz_generated"):
			api_client.quiz_generated.connect(_on_quiz_generated)
		if api_client.has_signal("quiz_generation_failed"):
			api_client.quiz_generation_failed.connect(_on_quiz_generation_failed)
		print("[INFO] 已连接 APIClient 以获取动态题目")
	else:
		print("[WARN] 未找到 APIClient, 将始终使用本地题库")

func start_quiz(quiz_id: String):
	"""开始答题"""
	self.quiz_id = quiz_id
	current_quiz = QuizManager.get_quiz(quiz_id)
	
	if current_quiz.is_empty():
		print("[ERROR] 答题不存在: ", quiz_id)
		return

	# 先尝试动态拉取题目, 若失败则回退到本地题库
	var total_questions = current_quiz.get("total_questions", 3)
	_request_or_use_fallback_questions(total_questions)


func _request_or_use_fallback_questions(total_questions: int) -> void:
	"""优先请求后端动态题目, 失败时回退本地"""
	if api_client:
		var npc_name: String = str(current_quiz.get("npc_name", ""))
		if npc_name != "":
			api_client.get_generated_quiz(quiz_id, npc_name, total_questions)
			# 等待异步回调, 此处先显示加载状态
			current_questions = []
			current_question_index = 0
			correct_count = 0
			answer_history.clear()
			_show_loading_state()
			return
	
	# 如果没有 api_client 或 npc_name, 直接使用本地题库
	_use_fallback_questions(total_questions)


func _use_fallback_questions(total_questions: int) -> void:
	current_questions = QuizManager.get_random_questions(quiz_id, total_questions)
	if current_questions.is_empty():
		print("[ERROR] 没有可用题目")
		return

	current_question_index = 0
	correct_count = 0
	answer_history.clear()  # 清空历史记录
	
	# ⭐ 重新获取节点引用（确保节点已加载）
	_ensure_node_references()
	
	# 验证关键节点
	if not options_container:
		print("[ERROR] OptionsContainer节点未找到！")
		print("[DEBUG] 尝试重新获取节点...")
		options_container = get_node_or_null("Control/Panel/OptionsWrapper/OptionsContainer")
		if not options_container:
			print("[ERROR] 无法找到OptionsContainer节点")
			return
	
	# 设置标题
	if title_label:
		title_label.text = current_quiz.get("title", "答题")
	
	# 显示UI
	visible = true
	print("[INFO] QuizUI visible设置为: ", visible)
	
	# 确保Panel也可见
	if panel:
		panel.visible = true
		print("[INFO] Panel visible设置为: ", panel.visible)
	
	# 禁用玩家移动
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_interacting(true)
	
	# 显示第一题
	display_question()
	
	print("[INFO] 开始答题: ", quiz_id, " 共", current_questions.size(), "题")


func _show_loading_state() -> void:
	"""动态题目加载中的简单提示"""
	_ensure_node_references()
	if title_label:
		title_label.text = current_quiz.get("title", "答题")
	if question_label:
		question_label.text = "正在为你准备与 李白 相关的题目..."
	if progress_label:
		progress_label.text = ""
	if feedback_label:
		feedback_label.text = ""
	visible = true


func _on_quiz_generated(generated_quiz_id: String, quiz_data: Dictionary) -> void:
	"""动态题目获取成功"""
	if generated_quiz_id != "" and generated_quiz_id != quiz_id:
		return
	
	var total_questions = current_quiz.get("total_questions", 3)
	var questions: Array = quiz_data.get("questions", [])
	
	# 将动态题目写入 QuizManager 缓存, 便于重用
	QuizManager.set_dynamic_questions(quiz_id, questions)
	
	if questions.is_empty():
		print("[WARN] 动态题目为空, 回退到本地题库")
		_use_fallback_questions(total_questions)
	else:
		current_questions = questions
		current_question_index = 0
		correct_count = 0
		answer_history.clear()
		# 重新进入常规展示流程
		_ensure_node_references()
		display_question()
		visible = true
		print("[INFO] 使用动态题目开始答题: ", quiz_id, " 共", current_questions.size(), "题")


func _on_quiz_generation_failed(failed_quiz_id: String, _error_message: String) -> void:
	"""动态题目获取失败, 回退到本地题库"""
	if failed_quiz_id != "" and failed_quiz_id != quiz_id:
		return
	var total_questions = current_quiz.get("total_questions", 3)
	print("[WARN] 动态题目获取失败, 使用本地题库")
	_use_fallback_questions(total_questions)

func _ensure_node_references():
	"""确保节点引用已获取"""
	if not panel:
		panel = get_node_or_null("Control/Panel")
	if not background_texture_rect:
		background_texture_rect = get_node_or_null("Control/Panel/BackgroundTexture")
	if not title_label:
		title_label = get_node_or_null("Control/Panel/TitleLabel")
	if not question_label:
		question_label = get_node_or_null("Control/Panel/QuestionLabel")
	if not options_container:
		options_container = get_node_or_null("Control/Panel/OptionsWrapper/OptionsContainer")
	if not progress_label:
		progress_label = get_node_or_null("Control/Panel/ProgressLabel")
	if not feedback_label:
		feedback_label = get_node_or_null("Control/Panel/FeedbackLabel")
	if not close_button:
		close_button = get_node_or_null("Control/Panel/CloseButton")
	
	# 验证节点
	print("[DEBUG] 节点引用状态:")
	print("  - panel: ", panel != null)
	print("  - background_texture_rect: ", background_texture_rect != null)
	print("  - title_label: ", title_label != null)
	print("  - question_label: ", question_label != null)
	print("  - options_container: ", options_container != null)
	print("  - progress_label: ", progress_label != null)
	print("  - feedback_label: ", feedback_label != null)
	print("  - close_button: ", close_button != null)

func display_question():
	"""显示当前问题"""
	if current_question_index >= current_questions.size():
		finish_quiz()
		return
	
	var question = current_questions[current_question_index]
	
	print("[DEBUG] 显示题目 %d: %s" % [current_question_index + 1, question["question"]])
	
	# 显示问题
	if question_label:
		question_label.text = question["question"]
		question_label.visible = true
		print("[DEBUG] 问题标签文本: ", question_label.text)
	
	# 显示进度
	if progress_label:
		progress_label.text = "进度: %d/%d" % [current_question_index + 1, current_questions.size()]
		progress_label.visible = true
	
	# 清空反馈
	if feedback_label:
		feedback_label.text = ""
		feedback_label.visible = false
	
	# 关闭按钮一直可用，不需要禁用
	# 更新历史按钮状态
	if history_button:
		history_button.visible = (answer_history.size() > 0)
	
	# 清空并创建选项按钮
	clear_options()
	create_option_buttons(question["options"])
	
	print("[DEBUG] 已创建 %d 个选项按钮" % question["options"].size())

func create_option_buttons(options: Array):
	"""创建选项按钮"""
	if not options_container:
		print("[ERROR] OptionsContainer未找到")
		return
	
	# 设置容器间距（使用导出变量，可在编辑器中调整）
	options_container.add_theme_constant_override("separation", option_spacing)
	
	# 确保容器是空的
	clear_options()
	
	# 根据是否有背景图决定按钮样式
	var use_traditional_style = background_texture != null
	
	# 使用导出变量中的按钮宽度（可在编辑器中调整）
	var button_width = option_button_width
	
	for i in range(options.size()):
		var button = Button.new()
		button.text = "%s. %s" % [char(65 + i), options[i]]  # A. 选项1, B. 选项2...
		button.custom_minimum_size = Vector2(button_width, 90)  # 宽度可配置，高度固定
		button.add_theme_font_size_override("font_size", option_button_font_size)  # 字体大小可配置
		
		# 设置按钮样式（传统卷轴风格）
		if use_traditional_style:
			_setup_traditional_button_style(button)
		else:
			_setup_default_button_style(button)
		
		button.pressed.connect(_on_option_selected.bind(i))
		options_container.add_child(button)
		print("[DEBUG] 创建选项按钮 %d: %s" % [i, button.text])
	
	print("[DEBUG] 已创建 %d 个选项按钮" % options.size())

func clear_options():
	"""清空选项按钮"""
	if not options_container:
		print("[WARN] OptionsContainer未找到，无法清空选项")
		return
	
	for child in options_container.get_children():
		child.queue_free()

func _on_option_selected(option_index: int):
	"""选项被选择"""
	var question = current_questions[current_question_index]
	
	# 禁用所有按钮（防止重复点击）
	for button in options_container.get_children():
		button.disabled = true
	
	# 记录答题历史
	var selected_option = question["options"][option_index]
	var correct_option = question["options"][question["correct"]]
	var is_correct = (option_index == question["correct"])
	
	answer_history.append({
		"question_index": current_question_index,
		"question": question["question"],
		"options": question["options"].duplicate(),
		"selected_option": selected_option,
		"selected_index": option_index,
		"correct_option": correct_option,
		"correct_index": question["correct"],
		"is_correct": is_correct
	})
	
	# 检查答案
	if is_correct:
		correct_count += 1
		show_feedback("回答正确！", Color.GREEN)
		print("[INFO] ✅ 回答正确")
		
		# ⭐ 显示答题正确奖励效果（传递已答对的题目数量）
		if has_node("/root/RewardEffectManager"):
			print("[DEBUG] 🎁 准备显示答题奖励: correct_count=", correct_count)
			RewardEffectManager.show_quiz_reward(correct_count)
		else:
			print("[ERROR] ⚠️ RewardEffectManager未找到，无法显示答题奖励")
	else:
		show_feedback("回答错误！正确答案是: %s" % correct_option, Color.RED)
		print("[INFO] ❌ 回答错误，正确答案是: ", correct_option)
	
	# 更新历史按钮状态
	if history_button:
		history_button.visible = true
	
	# 等待2秒后自动切换到下一题
	await get_tree().create_timer(2.0).timeout
	
	# 清空当前题目显示
	clear_current_question()
	
	# 切换到下一题
	current_question_index += 1
	display_question()

func clear_current_question():
	"""清空当前题目显示（准备显示下一题）"""
	# 清空问题文本
	if question_label:
		question_label.text = ""
	
	# 清空反馈
	if feedback_label:
		feedback_label.text = ""
		feedback_label.visible = false
	
	# 清空选项
	clear_options()

func show_feedback(message: String, color: Color):
	"""显示反馈"""
	if feedback_label:
		feedback_label.text = message
		feedback_label.add_theme_color_override("font_color", color)
		feedback_label.visible = true

func finish_quiz():
	"""完成答题"""
	var required = current_quiz.get("required_correct", current_questions.size())
	var passed = correct_count >= required
	
	# 显示结果
	if passed:
		show_feedback("恭喜！答题通过！答对了 %d/%d 题" % [correct_count, current_questions.size()], Color.GREEN)
		
		# 标记答题完成
		QuizManager.complete_quiz(quiz_id)
		
		# 解锁下一个区域
		var target_region = current_quiz.get("target_region", 0)
		if target_region > 0:
			RegionManager.unlock_region(target_region)
		
		print("[INFO] ✅ 答题通过！解锁区域 %d" % target_region)
	else:
		show_feedback("很遗憾，答题未通过。答对了 %d/%d 题，需要答对 %d 题" % [correct_count, current_questions.size(), required], Color.RED)
		print("[INFO] ❌ 答题未通过")
	
	# 关闭按钮一直可用，不需要启用
	# 显示历史按钮（如果有历史记录）
	if history_button and answer_history.size() > 0:
		history_button.visible = true
	
	# 等待2秒后自动关闭（如果用户没有手动点击关闭按钮）
	await get_tree().create_timer(2.0).timeout
	
	# 检查UI是否仍然可见（如果用户已经点击关闭按钮，这里会跳过）
	if visible:
		hide()
		
		# 恢复玩家移动
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.set_interacting(false)
		
		# 发送信号
		quiz_completed.emit(quiz_id, passed)

func _on_close_button_pressed():
	"""关闭按钮被点击（一直可用）"""
	print("[INFO] 用户点击关闭按钮")
	
	# 如果历史面板显示，先关闭历史面板
	if history_panel and history_panel.visible:
		history_panel.visible = false
		return
	
	hide()
	
	# 恢复玩家移动
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_interacting(false)
	
	# 如果答题已完成，发送完成信号
	if current_question_index >= current_questions.size():
		var required = current_quiz.get("required_correct", current_questions.size())
		var passed = correct_count >= required
		quiz_completed.emit(quiz_id, passed)

func _setup_text_colors():
	"""设置文字颜色（适配卷轴背景的浅色）"""
	# 如果有背景图，使用深色文字；否则使用浅色文字
	var text_color = Color.WHITE
	if background_texture:
		# 卷轴背景是浅色，使用深色文字
		text_color = Color(0.2, 0.2, 0.2)  # 深灰色，接近黑色
	
	if title_label:
		title_label.add_theme_color_override("font_color", text_color)
	
	if question_label:
		question_label.add_theme_color_override("font_color", text_color)
	
	if progress_label:
		progress_label.add_theme_color_override("font_color", text_color)
	
	if close_button:
		close_button.add_theme_color_override("font_color", text_color)

func _setup_traditional_button_style(button: Button):
	"""设置传统卷轴风格的按钮样式（青年时期：绿色主题）"""
	# 正常状态：浅绿色背景，深绿色边框
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.78, 0.9, 0.78, 0.9)  # 浅绿色，半透明
	normal_style.border_color = Color(0.18, 0.31, 0.09)  # 深绿色边框
	normal_style.border_width_left = 3
	normal_style.border_width_top = 3
	normal_style.border_width_right = 3
	normal_style.border_width_bottom = 3
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", normal_style)
	
	# 悬停状态：绿色背景
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.62, 0.31, 0.95)  # 绿色
	button.add_theme_stylebox_override("hover", hover_style)
	
	# 按下状态：深绿色背景
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.5, 0.2, 0.95)  # 深绿色
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# 禁用状态：灰色
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.8, 0.8, 0.8, 0.5)  # 浅灰色，半透明
	disabled_style.border_color = Color(0.5, 0.5, 0.5)  # 灰色边框
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	# 文字颜色：深色
	button.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	button.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.1))
	button.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
	button.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))

func _setup_default_button_style(button: Button):
	"""设置默认按钮样式（无背景图时使用）"""
	# 正常状态：深色半透明背景
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	normal_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", normal_style)
	
	# 悬停状态
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.3, 0.4, 0.9)
	button.add_theme_stylebox_override("hover", hover_style)
	
	# 文字颜色：浅色
	button.add_theme_color_override("font_color", Color.WHITE)

func _setup_close_button_style():
	"""设置关闭按钮样式，与进度标签一致"""
	if not close_button:
		return
	
	# 设置字体大小和颜色与进度标签一致
	var text_color = Color.WHITE
	if background_texture:
		text_color = Color(0.2, 0.2, 0.2)  # 深灰色，适配卷轴背景
	
	close_button.add_theme_font_size_override("font_size", 42)  # 与进度标签一致
	close_button.add_theme_color_override("font_color", text_color)
	
	# 设置按钮样式为透明背景（类似Label）
	var style_box = StyleBoxEmpty.new()
	close_button.add_theme_stylebox_override("normal", style_box)
	close_button.add_theme_stylebox_override("hover", style_box)
	close_button.add_theme_stylebox_override("pressed", style_box)
	
	# 悬停时稍微变亮
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 1.0, 1.0, 0.1)  # 半透明白色
	close_button.add_theme_stylebox_override("hover", hover_style)

func _create_history_button():
	"""创建历史查看按钮"""
	if not panel:
		return
	
	history_button = Button.new()
	history_button.text = "查看历史"
	history_button.name = "HistoryButton"
	history_button.visible = false  # 初始隐藏，有历史记录后显示
	
	# 设置位置：在进度标签和关闭按钮之间
	history_button.anchors_preset = Control.PRESET_BOTTOM_LEFT
	history_button.offset_left = 50
	history_button.offset_top = -100
	history_button.offset_right = 200
	history_button.offset_bottom = -40
	
	# 设置样式与进度标签一致
	history_button.add_theme_font_size_override("font_size", 42)
	var text_color = Color.WHITE
	if background_texture:
		text_color = Color(0.2, 0.2, 0.2)
	history_button.add_theme_color_override("font_color", text_color)
	
	var style_box = StyleBoxEmpty.new()
	history_button.add_theme_stylebox_override("normal", style_box)
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 1.0, 1.0, 0.1)
	history_button.add_theme_stylebox_override("hover", hover_style)
	
	history_button.pressed.connect(_on_history_button_pressed)
	panel.add_child(history_button)

func _create_history_panel():
	"""创建历史查看面板"""
	if not panel:
		return
	
	history_panel = Panel.new()
	history_panel.name = "HistoryPanel"
	history_panel.visible = false
	history_panel.anchors_preset = Control.PRESET_FULL_RECT
	history_panel.offset_left = 50
	history_panel.offset_top = 100
	history_panel.offset_right = -50
	history_panel.offset_bottom = -200
	
	# 设置背景样式
	var style_box = StyleBoxFlat.new()
	if background_texture:
		style_box.bg_color = Color(0.95, 0.95, 0.9, 0.98)  # 浅色背景
	else:
		style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)  # 深色背景
	style_box.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	history_panel.add_theme_stylebox_override("panel", style_box)
	
	# 创建滚动容器
	var scroll_container = ScrollContainer.new()
	scroll_container.anchors_preset = Control.PRESET_FULL_RECT
	scroll_container.offset_left = 20
	scroll_container.offset_top = 60
	scroll_container.offset_right = -20
	scroll_container.offset_bottom = -60
	
	# 创建内容容器
	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	scroll_container.add_child(content_container)
	history_panel.add_child(scroll_container)
	
	# 创建标题
	var title = Label.new()
	title.text = "答题历史"
	title.add_theme_font_size_override("font_size", 56)
	var text_color = Color.WHITE
	if background_texture:
		text_color = Color(0.2, 0.2, 0.2)
	title.add_theme_color_override("font_color", text_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_TOP_WIDE
	title.offset_bottom = 50
	history_panel.add_child(title)
	
	# 创建关闭按钮
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	close_btn.offset_left = -100
	close_btn.offset_top = 10
	close_btn.offset_right = -20
	close_btn.offset_bottom = 50
	close_btn.pressed.connect(func(): history_panel.visible = false)
	close_btn.add_theme_font_size_override("font_size", 42)
	close_btn.add_theme_color_override("font_color", text_color)
	history_panel.add_child(close_btn)
	
	panel.add_child(history_panel)

func _on_history_button_pressed():
	"""历史按钮被点击"""
	if not history_panel:
		return
	
	history_panel.visible = not history_panel.visible
	
	if history_panel.visible:
		_update_history_display()

func _update_history_display():
	"""更新历史显示"""
	if not history_panel:
		return
	
	var content_container = history_panel.get_node_or_null("ScrollContainer/ContentContainer")
	if not content_container:
		return
	
	# 清空现有内容
	for child in content_container.get_children():
		child.queue_free()
	
	# 显示每道题的历史
	for i in range(answer_history.size()):
		var history_item = answer_history[i]
		var item_panel = _create_history_item(history_item, i + 1)
		content_container.add_child(item_panel)

func _create_history_item(history_item: Dictionary, question_num: int) -> Panel:
	"""创建单个历史题目显示项"""
	var item_panel = Panel.new()
	
	# 设置样式
	var style_box = StyleBoxFlat.new()
	if background_texture:
		style_box.bg_color = Color(1.0, 1.0, 1.0, 0.5)  # 半透明白色
	else:
		style_box.bg_color = Color(0.2, 0.2, 0.3, 0.5)  # 半透明深色
	style_box.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	item_panel.add_theme_stylebox_override("panel", style_box)
	
	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_FULL_RECT
	container.offset_left = 20
	container.offset_top = 20
	container.offset_right = -20
	container.offset_bottom = -20
	
	# 题目编号和问题
	var question_label = Label.new()
	question_label.text = "第 %d 题: %s" % [question_num, history_item["question"]]
	question_label.add_theme_font_size_override("font_size", 40)
	var text_color = Color.WHITE
	if background_texture:
		text_color = Color(0.2, 0.2, 0.2)
	question_label.add_theme_color_override("font_color", text_color)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(question_label)
	
	# 显示所有选项
	for j in range(history_item["options"].size()):
		var option_label = Label.new()
		var option_text = "%s. %s" % [char(65 + j), history_item["options"][j]]
		
		# 标记正确答案
		if j == history_item["correct_index"]:
			option_text += " ✓ (正确答案)"
			option_label.add_theme_color_override("font_color", Color.GREEN)
		# 标记用户选择的错误答案
		elif j == history_item["selected_index"] and not history_item["is_correct"]:
			option_text += " ✗ (你的选择)"
			option_label.add_theme_color_override("font_color", Color.RED)
		else:
			if background_texture:
				option_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
			else:
				option_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		
		option_label.text = option_text
		option_label.add_theme_font_size_override("font_size", 36)
		option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(option_label)
	
	# 显示结果
	var result_label = Label.new()
	if history_item["is_correct"]:
		result_label.text = "✓ 回答正确"
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text = "✗ 回答错误，你选择了: %s" % history_item["selected_option"]
		result_label.add_theme_color_override("font_color", Color.RED)
	result_label.add_theme_font_size_override("font_size", 36)
	container.add_child(result_label)
	
	item_panel.add_child(container)
	item_panel.custom_minimum_size = Vector2(0, 200)  # 设置最小高度
	
	return item_panel
