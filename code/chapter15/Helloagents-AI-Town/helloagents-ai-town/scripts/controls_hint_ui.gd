# 按键提示UI脚本
extends CanvasLayer

@onready var hint_label: Label = $Control/HintLabel

func _ready():
	"""初始化"""
	# 设置标签样式
	if hint_label:
		# 增大字体，适合青少年
		hint_label.add_theme_font_size_override("font_size", 32)
		# 设置文字颜色为浅灰色，半透明
		hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
		# 设置背景（可选）
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.0, 0.0, 0.0, 0.5)
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		hint_label.add_theme_stylebox_override("normal", style_box)
		print("[INFO] 按键提示UI已初始化")

