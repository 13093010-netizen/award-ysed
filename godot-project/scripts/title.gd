extends Control
## 開場畫面：Logo + 開始按鈕（按開始會先播故事；下方選關可直接跳關）

signal start_pressed
signal level_selected(i: int)

const Art = preload("res://scripts/art.gd")

var t := 0.0
var btn: Button
var sel_btns: Array = []
var font: Font


func _ready() -> void:
	font = get_theme_font("font", "Label")
	btn = Button.new()
	btn.text = "開始"
	btn.add_theme_font_size_override("font_size", 64)
	btn.custom_minimum_size = Vector2(340, 120)
	btn.size = btn.custom_minimum_size
	add_child(btn)
	btn.pressed.connect(func(): start_pressed.emit())
	# 選關（方便測試）
	for i in 6:
		var b := Button.new()
		b.text = "第%d關" % (i + 1) if i < 5 else "終章"
		b.add_theme_font_size_override("font_size", 32)
		b.custom_minimum_size = Vector2(140, 64)
		b.size = b.custom_minimum_size
		b.pressed.connect(func(): level_selected.emit(i))
		add_child(b)
		sel_btns.append(b)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	btn.position = Vector2(size.x / 2 - btn.size.x / 2, size.y * 0.72)
	for i in sel_btns.size():
		sel_btns[i].position = Vector2(size.x / 2 - 470 + i * 160, size.y * 0.72 + 140)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("#bfe3f2"))
	# 遠山與草地
	Art.ellipse(self, Vector2(w * 0.2, h * 0.68), Vector2(w * 0.45, h * 0.18), Color("#a9cf78"))
	Art.ellipse(self, Vector2(w * 0.85, h * 0.7), Vector2(w * 0.4, h * 0.16), Color("#98c268"))
	Art.checker(self, Rect2(0, h * 0.68, w, h * 0.32), Color("#8db85c"), Color("#82ad52"), 64)
	# 前景一排麥子
	for i in 26:
		var x := w * (i + 0.5) / 26.0
		Art.wheat(self, Vector2(x, h + 10), 120 + (i % 3) * 18, Color("#e3b23c"), sin(t * 1.6 + i * 0.5) * 0.15)

	# Logo
	var c := Vector2(w / 2, h * 0.33 + sin(t * 1.5) * 6)
	draw_circle(c, 180, Color("#f3c74f"))
	draw_circle(c, 158, Color("#fff4d2"))
	for i in 12:
		var a := t * 0.3 + i * TAU / 12
		draw_line(c + Vector2(cos(a), sin(a)) * 190, c + Vector2(cos(a), sin(a)) * 215, Color("#f3c74f"), 8, false)
	Art.wheat(self, c + Vector2(-84, 120), 200, Color("#d79a2b"), 0.0, 7)
	Art.wheat(self, c + Vector2(0, 128), 230, Color("#e3b23c"), 0.0, 7)
	Art.wheat(self, c + Vector2(84, 120), 200, Color("#d79a2b"), 0.0, 7)

	var ty := c.y + 280
	# 像參考圖那種粗外框大標題：外層金色、內層深咖啡、字是米白色
	draw_string_outline(font, Vector2(0, ty + 8), "守護阿麥伯的麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 96, 36, Color("#3a240c"))
	draw_string_outline(font, Vector2(0, ty), "守護阿麥伯的麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 96, 32, Color("#f3c74f"))
	draw_string_outline(font, Vector2(0, ty), "守護阿麥伯的麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 96, 16, Color("#3a240c"))
	draw_string(font, Vector2(0, ty), "守護阿麥伯的麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 96, Color("#fff8e6"))
	draw_string(font, Vector2(0, ty + 84), "替阿公守住這塊充滿回憶的麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 32, Color("#5a3a14"))
