# 主菜单脚本
extends Control

# 节点引用
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var exit_button: Button = $VBoxContainer/ExitButton
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var background_image: TextureRect = $BackgroundImage

# 主游戏场景路径
const MAIN_SCENE_PATH = "res://scenes/main.tscn"

# 背景图片路径（如果图片不存在，会使用纯色背景）
const BACKGROUND_IMAGE_PATH = "res://assets/ui/main_menu_background.png"

func _ready():
	"""初始化主菜单"""
	print("[INFO] 主菜单初始化")
	
	# 加载背景图片
	_load_background_image()
	
	# 连接按钮信号
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
	
	# 设置UI样式
	_setup_ui_style()

func _load_background_image():
	"""加载背景图片"""
	if background_image:
		# 检查图片文件是否存在
		if ResourceLoader.exists(BACKGROUND_IMAGE_PATH):
			var texture = load(BACKGROUND_IMAGE_PATH)
			if texture:
				background_image.texture = texture
				print("[INFO] 主菜单背景图片已加载: ", BACKGROUND_IMAGE_PATH)
			else:
				print("[WARN] 无法加载背景图片: ", BACKGROUND_IMAGE_PATH)
		else:
			print("[INFO] 背景图片不存在，使用纯色背景: ", BACKGROUND_IMAGE_PATH)
			# 如果图片不存在，隐藏TextureRect，显示ColorRect背景
			background_image.visible = false

func _setup_ui_style():
	"""设置UI样式"""
	# 设置标题样式 - 使用金色，更醒目
	if title_label:
		title_label.add_theme_font_size_override("font_size", 120)
		title_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 1.0))  # 金色
		title_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.15, 0.1, 0.9))
		title_label.add_theme_constant_override("shadow_offset_x", 6)
		title_label.add_theme_constant_override("shadow_offset_y", 6)
	
	# 设置副标题样式 - 使用青色，与标题形成对比
	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", 64)
		subtitle_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 1.0))  # 青色
		subtitle_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.2, 0.3, 0.7))
		subtitle_label.add_theme_constant_override("shadow_offset_x", 3)
		subtitle_label.add_theme_constant_override("shadow_offset_y", 3)
	
	# 设置开始按钮样式
	if start_button:
		start_button.add_theme_font_size_override("font_size", 64)
		_setup_button_style(start_button, Color(0.2, 0.7, 0.3, 1.0), Color(0.3, 0.8, 0.4, 1.0))
	
	# 设置退出按钮样式
	if exit_button:
		exit_button.add_theme_font_size_override("font_size", 64)
		_setup_button_style(exit_button, Color(0.7, 0.2, 0.2, 1.0), Color(0.8, 0.3, 0.3, 1.0))

func _setup_button_style(button: Button, normal_color: Color, hover_color: Color):
	"""设置按钮样式"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = normal_color
	style_normal.border_color = Color(0.9, 0.85, 0.7, 1.0)
	style_normal.border_width_left = 4
	style_normal.border_width_top = 4
	style_normal.border_width_right = 4
	style_normal.border_width_bottom = 4
	style_normal.corner_radius_top_left = 12
	style_normal.corner_radius_top_right = 12
	style_normal.corner_radius_bottom_left = 12
	style_normal.corner_radius_bottom_right = 12
	style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style_normal.shadow_size = 8
	style_normal.shadow_offset = Vector2(0, 4)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = hover_color
	style_hover.shadow_size = 10
	style_hover.shadow_offset = Vector2(0, 6)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = normal_color.darkened(0.2)
	style_pressed.shadow_size = 4
	style_pressed.shadow_offset = Vector2(0, 2)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	# 设置按钮文字颜色
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.8, 1.0))

func _on_start_button_pressed():
	"""开始游戏按钮点击"""
	print("[INFO] 点击开始游戏")
	# 切换到主游戏场景
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _on_exit_button_pressed():
	"""退出游戏按钮点击"""
	print("[INFO] 点击退出游戏")
	# 退出游戏
	get_tree().quit()
